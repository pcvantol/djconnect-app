# DJConnect App Engineering Status

## 2026-10-21 — Apple client consolidation / PR169

PR169 merged the reviewed-by-author client candidate `d2b1482` as `9980279`.
Main CI/coverage 39626856219 and formal reconciliation 39628569024 PASS; canonical
integrity, runner/main binding, coverage ZIP digest and 12/12 required checks are
verified. This is source qualification, not full product acceptance.

Ordinary development build 40405 is installed, signature/full-bundle verified
and running on Mac mini. iPad installation lost its connection and its installed
version is unconfirmed. iPhone/Watch are deferred by the owner until tomorrow;
MacBook is unreachable. No data wipe, uninstall or pairing reset occurred.

The approved cleanup removed 79 stale local branches with original history held
under two local archive tags, plus one exact-duplicate temporary recovery app,
one duplicate test-products directory and the owned simulator. One worktree,
no stashes; unique historical products/bundles and test evidence remain.

Music DNA artwork, current Track Insight, sparse automatic contributions,
historical-track playback and genuine VibeCast SDK/QA remain separately open.
See [the exact delivery receipt](docs/feedback/APPLE_OCT21_MAIN_DELIVERY_20261021.json) for hashes and remaining boundaries.
This separate documentary Finalization changes no compiled inputs.

## 2026-10-21 — Native display-consent qualification / PR167

Source [PR167](https://github.com/pcvantol/djconnect-app/pull/167) merged approved
`8462454f4c662259b0fd47f4bd78c2545f41daa0` as
`b90b40071f9eadbe81dc084f815213a4fabd066e`; both trees are
`cb5964628621a7543419e5a373a4509180e9844f`. Only five test/tooling/evidence
files changed; production sources and shipping targets are unchanged.

The original isolated actual-iOS-model qualification recorded18PASS/0fail/0skip
and13 targeted Mac tests PASS. PR CI39555114674, main CI/coverage39555773003 and
formal reconciliation39558770094 PASS. Independent durable-asset digest,
canonical integrity,12/12required checks, runner main-SHA and coverage ZIP/main
binding are verified in [the portable source receipt](docs/feedback/APPLE_CONSENT_167_SOURCE_EVIDENCE_20261021.json).
The separate TDE-observe workflow39555772553 succeeded, but its assessment and
qualification report BLOCKED: `store requires validated canonical evidence`.
No substantive TDE qualification or independent review is claimed.

Development-signed build40402 from exact merged source is installed and
independently read back on iPhone, iPad, Mac mini and MacBook. Both Mac
executables match the candidate, strict deep signatures pass and ordinary apps
are running. All208source/resource/project/dependency inputs match merged main.
This documentary Finalization changes no compiled inputs. Later night-work
commits remain locally preserved and excluded from publication/installation.

Owner-requested cleanup removed75local and MacBook recovery-app copies,
including each replacement's temporary backup only after verification.
Current apps, data/pairings, Git/source, unique test evidence and local night
branches remain preserved. No new recovery bundle or automation extension.
The stuck old PR TDE job39555113965 was cancelled with explicit owner approval;
a targeted Apple listener restart restored the queue without a running worker.

Repository State: source-main is qualified; `MERGED_UNRECONCILED` until this
separate documentary Finalization merges, then `MERGED_RECONCILED` for167.
Workspace State: `CLEAN_PRESERVED`. Product Acceptance: `PARTIAL`.
Synthetic model tests and install readbacks do not close native button,
physical/audio, VoiceOver, installed-HA/receiver, producer or full-chain SDK
gates. Watch remains deferred. No Core/backend/provider/OS-permission change.

## Current consolidated Apple source — 2026-10-20

**Repository Status:** Existing Apple work consolidated through protected merges;
product acceptance remains partial. Installation is distinct from source delivery.

**Management Summary:** [PR162](https://github.com/pcvantol/djconnect-app/pull/162)
merged as `36120cb7e375404d8cde4eb21773dd8311b8fa92` from reviewed
`460725b1e6d04032c81b3e8d79714e7387074890`; both trees are
`ed20ef248b4ccbfca0a67ce79bfa4500c137ccbd`. The preceding merged
[Finalization165](https://github.com/pcvantol/djconnect-app/pull/165) is
`8adbdac5ea3b1cdd9e14df67f9608f374610dda0`, reconciling VibeCast164.
Exact162 review6299801611 found no major issues; CI39485176078 and required
Trusted Delivery39485175962 succeeded. Earlier51e review found two realP2s;
both were reproduced and corrected before this reviewed merge.

Combined local73XCTest(two intentional skips/zero failures)+1011SwiftTesting
checks in13suites passed, including16paired Forecast scenarios. Existing-signed
iOS/Watch and Mac40401 builds and strict signatures passed. Build40401 is
installed and independently read back on iPhone, Mac mini and MacBook; the
Mac archive/executable hashes match and previous Mac apps remain recoverable.
These artifacts were built from the exact reviewed source whose tree equals
merged162; this governance-only Finalization changes no compiled inputs.

**Roadmap Position:** Source consolidation is complete for164/162. Forecast
remains Core-authored intentions, and explicit current-Session screen consent
stays separate from legacy handoff. No new product capability is selected.

**Rolling Horizon:** Finish this transaction's protected Finalization,
exact-main readback and safe cleanup only. No additional execution horizon is
activated; canonical platform planning remains authoritative.

**Blocked Items:** Positive native CoreB lookup/confirm/withdrawal, VibeCastA
admission/enrollment/assertion/exact-submit full chain, Forecast accessibility/
scroll/current-server/provider proof, native speech/audibility and qualified
Golden/producer consumption remain open. Source/build/install evidence does
not close those product gates. App launch and register87 publication remain
unperformed after automatic approval rejection and pending specific questions.

**Deferred Items:** The owner explicitly deferred Watch unlocking and iPad
connectivity while other installations finish. Neither is installed40401.
Brand2.0.1 adoption and new SDK/provider experiments are outside consolidation.

**Repository State:** `MERGED_UNRECONCILED` for162 until this separate
Finalization merges, then `MERGED_RECONCILED` for this consolidation.
**Workspace State:** `CLEAN_PRESERVED`; eight proven-completed local branches
were removed normally and stale remote refs pruned. Unique/ambiguous histories
and a branch refused by normal deletion remain preserved, with an independently
verified all-ref recovery bundle. Finalization cleanup/readback still follows.
Earlier sections below are historical snapshots.

## Previous PR164 consolidation snapshot — 2026-10-20

The owner selected consolidation of existing Apple work and installation on all
Apple devices. [PR #164](https://github.com/pcvantol/djconnect-app/pull/164)
merged normally as `f5dac83da8d90a23db8a50a6b9a45a4e69a1fcb8` from reviewed
`2e00228eacecda1ef42ee199b6fd1fab8e4a93f2`; both trees are
`41c90c8df30f76e990312089c5e46ce86c7003cd`. Candidate CI and Trusted Delivery
passed, and exact code review completed without findings. The separate owning
security summary has no completion receipt; no separate security GO is claimed.

The source includes VibeCast QR preparation and separate explicit current-Session
screen consent in the native UI. Local verification passed 73 XCTest tests
(two intentional skips), 1000 Swift Testing tests, the unsigned iOS build and
1355 localization keys. Source consolidation is not product acceptance:
positive native consent lookup/confirmation/withdrawal qualification and the
App Attest admission/enrollment/assertion/exact-submit chain remain open.

[PR #162](https://github.com/pcvantol/djconnect-app/pull/162) still requires
current-main integration and protected delivery. Device installation is now
explicitly authorized through existing signing routes; installed proof is
pending. Existing Profile/pairing state, unique refs, work and evidence remain
preserved. Golden execution remains gated on qualified Core and explicit run
conditions; pending producer consumers and Brand2.0.1 adoption remain open.
No new feature or model/provider budget is selected.

Repository State: `MERGED_UNRECONCILED` until this governance-only Finalization
merges; then `MERGED_RECONCILED` for PR164. Workspace State: `CLEAN_PRESERVED`,
with cleanup pending after consolidation. Earlier sections below are historical.
See [the consolidation history](docs/history/prompts/2026-10-20-apple-164-consolidation-finalization.md).

## Current Session header refinement — 2026-10-12

Owner-requested header correction is source-delivered through [PR #101](https://github.com/pcvantol/djconnect-app/pull/101), reviewed head `c5af1f07c8440a6e6f90b0a186d04aaea07f0dd4`, protected source-main `03d02a40c4caa9b5d37c8767e49f87b88cf106a3`. Both trees are `af668f407b18246157217157ceafacb7e4d51d2b`; parent is prior reconciled main `c045473`. Official Owner Authorization38210333937 and premerge CI38208915501 PASS. Source-main CI/coverage38210411713 and durable exact-SHA evidence38211003692 independently verified PASS. This separate [Finalization candidate](docs/history/prompts/2026-10-12-apple-session-header-finalization.md) requires its own publication/protected-merge authority.

Build40015 keeps current music/artwork left and current DJ/quiet/recovery content right, including compact widths; current header stays pinned. Compact full Spotify logo/source links and at least44pt hit areas retain attribution. Native iPhone/iPad tests and actual temporary Mac AX/screenshots PASS; independent technical and bounded visual reviews GO. These Demo captures do not qualify actual artwork/Spotify provider retrieval, XXXL/long-language stress or real-provider acceptance.473 reported general tests include8 gated producer skips. Product Acceptance: `PARTIAL`.

Repository State: `MERGED_UNRECONCILED` until separately approved protected Finalization publication/merge and exact-main readback. Previous PR99/100 is completed/reconciled; the prior sections below are historical snapshots. iPad/MacBook ordinary40014 were privately installed under separate owner authority; this refinement has not installed40015. One reused Apple writer; original separate WIP and terminal #95/#96 preserved; temporary Mac test stopped. No Core changes, new install, Store release or HA deployment is authorized by this document.


## Previous Apple Session UI/Demo/welcome followup — snapshot 2026-10-12

Owner-requested followup is source delivered through
[PR99](https://github.com/pcvantol/djconnect-app/pull/99), reviewed
1b78af9d2aa94176ed79c0337ae3f780894edf38, protected source-main
0e0deed212107b8ab36a7cfa0b3d32ed2c388231; tree
6dae800c84d76b6dd81b430314af284c4cadc4b7 equals the approved candidate.
Official Owner Authorization38200426205, source-mainCI/coverage38200531242
and durable exact-SHA evidence38200987651 independently verified PASS.

Current scope is native pinned/newest-first Session UI, archive styling/time/
refresh, separate player routes, server-owned mood and localized privacy/output
handling, explicit representative Demo active/readonly history and the idle
welcomehero. Native iPhone/iPad/Mac software proof/reviews are bounded;473
reported general tests include8 environment-gated producer skips, separately
from dedicated actual paired/native runs. Demo voice is scripted and captures
no audio. Producer artwork, current real-provider/physical acceptance and
latest installation remain open, not silently replaced by demo screenshots.

Repository State: `MERGED_UNRECONCILED` until this separate exact-head
[Finalization candidate](docs/history/prompts/2026-10-12-apple-session-ui-demo-welcome-finalization.md)
is authorized, protected published and exact main/evidence read back. Intended
state then `MERGED_RECONCILED`; Product Acceptance: `PARTIAL`. One reused Apple
writer; original separate WIP, terminal #95/#96, completed predecessors #97/#98
and recoverable evidence retained. Own temporary Mac/current UI lab stopped.
No next Core/Apple capability, installation, HA deployment or Store release
is authorized by this status record.


## Previous conversation/history source — snapshot 2026-10-10

`DJC-APPLE-SESSION-CONVERSATION-HISTORY-V1-20261008`, with
`DJC-SESSION-FLOW-TEXT-SEARCH-V1-20261008`, is source-delivered through
[PR #97](https://github.com/pcvantol/djconnect-app/pull/97). Exact reviewed head
`d49aa9b2aca5f4affd2e15e0ae60b1e8c32fefb1` protected squash merged to
`65c744b6a7d1f1a2620af7283dc8df1dcc6a8e0a`; both trees are
`2b202e8e96814c5f189b1aa76ff16586196202ec`. Official exact-SHA
[Owner Authorization38051518758](https://github.com/pcvantol/djconnect/actions/runs/38051518758)
PASS; no admin merge bypass. The same Apple writer and original separate WIP
were preserved. Closed #95/#96 remain terminal.

Native Profile conversation, readonly archived Sessions, historical Ask DJ
matches/exact-entry Open, text search and ordinary paired live subscriptions
now share the actual Core-owned contracts and native decode/state/render route.
Independent iOS More → Now Playing and macOS sidebar player remain reachable;
navigation preserves Session-ID and complete playback projection. No local
DJ intelligence or private conversation broadcast is introduced.

Local457 Swift tests, actual paired10 tests (repeated with privacy-safe wire
observation), native iPhone/iPad/Mac proof, five-language1022-key checks and
independent technical/UX source review PASS. Physical iPhone40012 spoken
question/answer is owner-reported on earlier sourcec7a711b. Genuine Mac spoken
input remains unqualified at the owner's explicit unavailability; installed
HA/current physical live, physical speaker playback and Music DNA activation
are not inferred from the isolated configured-source lab. Product acceptance
is therefore PARTIAL, not a claim that every real-device requirement passed.

Exact source-mainCI38051574012/coverage and automatic SHA-evidence38052015643
PASS; downloaded formal JSON hash/integrity/redaction validated against the
exact canonical policy. Separate Finalization publication is being reconciled. See the
[Finalization snapshot](docs/history/prompts/2026-10-10-apple-session-conversation-history-finalization.md),
[native evidence](docs/verification/SESSION_CONVERSATION_HISTORY_NATIVE_EVIDENCE.md)
and [owning #87](https://github.com/pcvantol/djconnect-app/issues/87).
The unchanged optional TDE observe workflow failed because its Python3.9
runtime is below the published TDE1.1.1 minimum3.11; that assessment is NOT_RUN,
not a technical qualification PASS. No new capability, Store/TestFlight,
installation, HA deployment or Core writer is authorized by this record.

## Previous closed Apple assignment — 2026-10-08

`DJC-APPLE-MOMENT-FIRST-SESSION-V1-20261008` bron is beschermd gemergd:
[Apple #95](https://github.com/pcvantol/djconnect-app/pull/95), reviewed head
`d57e7a441a05c455ed05e33fb6bc30fba3d74873`, exact main
`a4cb7ed2cc332499f784eb40c822a1983a9e5289`, gedeelde tree
`18a1fd935c52ff5f63db77d422349e4c3737eb65`. De oorspronkelijke
Apple WIP bleef bewaard; slechts de geïsoleerde checkout was schrijver.

De source-merge is exact-main gekwalificeerd: main-CI
[37811802408](https://github.com/pcvantol/djconnect-app/actions/runs/37811802408)
en interne SHA-evidence
[37812663643](https://github.com/pcvantol/djconnect-app/actions/runs/37812663643)
zijn PASS. Deze afzonderlijke Finalization-documenten verzoenen de bronstatus,
het oorspronkelijke WIP en de aanvullende productafhankelijkheden. Het definitieve protected-merge-, publicatie- en cleanup-readback voor
dit documentpakket wordt na uitvoering in owning
[#87](https://github.com/pcvantol/djconnect-app/issues/87) geregistreerd.
Native iPhone/iPad/Mac met werkelijke pinned producer→owner transport→state→
SwiftUI, beide spelersituaties, zes netwerkgevallen, 408 reguliere tests,
vijf talen en onafhankelijke technische/UX reviews slagen. Bewijs en grenzen:
[Finalization-record](docs/history/prompts/2026-10-08-apple-moment-first-session-finalization.md),
[assessment](docs/APPLE_MOMENT_FIRST_SESSION_ASSESSMENT.md) en
[owning #87](https://github.com/pcvantol/djconnect-app/issues/87).

Gespreks-/historieaanvulling6061498264 is afhankelijk van nog te leveren
Core-contracten, geregistreerd in [#1101 comment6064346207](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6064346207)
voor een gerelateerde Apple vervolg-PR vóór pickup. #95 levert de actuele
Moment/Flow en onafhankelijke speler, geen persoonlijke archief/conversatieclaim.
Cast/Pages en LG hostkwalificatie behouden aparte grenzen. Geen nieuwe schrijver,
Store-release, certificaat, fysieke installatie of HA-deployment.

The previous VibeCast slice is closed by #87 comments 6010273946 and
6010386668. The following predecessor sections retain their historical freeze
points and do not reopen that assignment.


## VibeCast Session locale handoff

Apple [PR #93](https://github.com/pcvantol/djconnect-app/pull/93) merged the
independently reviewed Session-start locale handoff as exact main
`f8e4bf9d8e4096983a04502245babd864abb04b2` from head
`d7292b29851ce81f55c436b97e72e1ef8ddcc23a`. The reviewed source and merge
trees are identical. Exact-main
[CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355321818),
[Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355322019)
and [SHA-bound evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37355998819)
succeeded. The internal prerelease `internal-ha-f8e4bf9d8e4096983a04502245babd864abb04b2`
targets that merge and contains one qualification JSON with SHA-256
`ff90ebfadb70d29c167abee96fe4ffd900d347d461a7afecb99733388d96cde1`.
No signing, public release, production deployment or workflow change ran.

The Apple Session-start request now sends the app's normalized BCP-47 locale
alongside the selected mood. Core exact main
`dfd78cca1f128285527631fdc4a06de560cad435` consumes that value and freezes the
five-language family in the backend-owned Session. Local qualification passed
all 401 Swift tests, the unsigned iOS Simulator build, 976 localization keys
and 29 HTTP contract routes; independent review found no actionable issue.

`PI_QUAL=OPEN` remains accurate until a signed candidate built from the exact
Apple merge is installed on the physical iPhone and proves the live
nonterminal update, reconnect, Runtime-end cleanup and token boundary on the
physical portrait Pi. This same first slice remains active and selects no
second product item. Repository State: `MERGED_RECONCILED` after this
governance-only Finalization merges. Workspace State: `WORKSPACE_READY` only
after mandatory cleanup.

## VibeCast Pi decoder source reconciliation

Apple [PR #91](https://github.com/pcvantol/djconnect-app/pull/91) merged the
independently reviewed Session decoder correction as exact main
`29f3ad55d74c155fbab51c039358cea871d4c512` from head
`6221beacb178bd26e614411c32c97ee646138165`. Exact-main
[CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330425),
[Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330165)
and [SHA-bound evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37214736801)
succeeded. The existing internal prerelease has one qualification JSON; no
signing, public release, production deployment or workflow change ran.

The precommit local candidate was observed with a paired iPhone and physical
portrait Pi through owner approval, live snapshot, WebSocket reconnect,
Runtime-end cleanup and no durable browser token. The installed binary was
not separately bound to the later reviewed head or merge SHA. A separate
nonterminal update remains unproven on HA-dev: its Profile
Platform default backend is `later_manual`. The Spotify-authorized iOS entry
already has `spotify_direct` in its options, but the normal options flow does
not change the profile default backend. No HA-dev setting was changed.
Source/browser contract tests do not replace that live receipt. `PI_QUAL=OPEN`
and the same first slice remain active. The
canonical Core Execution Horizon remains the only portfolio authority; this
record selects no second slice. Repository State: `MERGED_RECONCILED` after this
governance-only Finalization merges. Workspace State: `WORKSPACE_READY` only
after mandatory local cleanup.

## Earlier reconciled engineering state

Status: macOS runner workspace retention reconciled

Repository: `pcvantol/djconnect-app`

## Reconciled Engineering State

PR [#70](https://github.com/pcvantol/djconnect-app/pull/70), **Add runner
workspace retention cleanup**, merged into `main` as
`1711458d8d6a2171914e6788b4fe9942f20022d4`.

The existing daily `com.djconnect.ci-tooling-maintenance` LaunchAgent now
reclaims only Git-ignored output from inactive runner worktrees and runner
diagnostics older than fourteen days. Its first canonical execution succeeded:
one inactive ESP32 workspace was cleaned, a recently active Apple workspace
was preserved, and fifteen expired diagnostics were removed. Runner binaries,
update state, Actions caches, source, published artifacts and formal evidence
remain excluded. The recorded Docker Desktop cask update remains an interactive
administrator maintenance item, not a runner-cleanup failure.

Repository State: `MERGED_RECONCILED`.
Workspace State: `WORKSPACE_READY`.

## Earlier Completion Context

PR [#52](https://github.com/pcvantol/djconnect-app/pull/52), **Implement Track
Insight Apple native sharing**, merged into `main` as
`0cdf0b529d51cf8631010d08bd64cc75d1e6a5c4`.

The implementation qualifies the existing `TrackInsightShareRenderer`,
`TrackInsightShareService` and SwiftUI `ShareLink` path. Track Insight remains
the sole producer and Apple the sole Renderer Host. The local payload excludes
Music DNA, Profile, Performance Memory, Planner/Runtime context, provider
payloads, Ask DJ history, credentials, tokens, device IDs and installation IDs.

Decision: `TRACK_INSIGHT_APPLE_SHARING_IMPLEMENTED`.
