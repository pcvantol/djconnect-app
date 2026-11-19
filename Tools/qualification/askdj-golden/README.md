# Real-client Ask DJ Golden integration qualification

Owner-selected pre-production integration test set. This is manual opt-in test
orchestration, not an ordinary app feature, production test endpoint, provider
client, automatic paid CI job or release authorization.

## What is implemented

- Exact catalogue derived from Core main
  `8b221d07fe2215d9516d18fe92c832332c7a16ab`,
  `docs/verification/fixtures/askdj_golden_release_matrix_v1.json`:
  **39 families / 167 steps**, preserving IDs, order, questions, model policies,
  expected outcomes and owning Core tests. `core-catalog.json` records the original
  source SHA256. Its own pinned SHA256 is enforced by Python and native code.
- Whole-family selection and a private, explicitly unarmed plan. Complete chains
  stay in order; the harness does not turn prose into new recommendations or
  rewrite Core's expected semantics.
- `AskDJGoldenIntegrationTests.testRealPairedSessionGolden` runs **inside the
  ordinary paired native app**, using its own credentials and
  `DJConnectAppModel.sendAskDJText`, the same method used by the composer. It
  requires the canonical Profile conversation, exact active disposable Session,
  Profile, app bundle/build and executable hash. Demo, monkey, unpaired, stale
  source, wrong host, mismatched context and unsupported locale fail before sends.
- Each actual client-generated message ID is captured before waiting. The real
  answer must be accepted, reopened through ordinary history and bound to the
  same server turn/client ID. The actual `AskDJMessageBubble` is rendered in a bounded native viewport. Private receipts
  contain hashes/revisions, not bearer tokens, raw prompts/answers or account URLs.
- Bounded plan: <=40 submissions, <=40 reserved model attempts, currently <=2
  declared attempts/turn, <=120s/turn and <=600s run timer. The URLSession is
  cancelled at the wall limit. No automatic scenario retry, clearing history,
  Session ending, output selection or test fixture creation. A run marker is
  exclusive and persists after failure: uncertainty cannot silently resend.
- The client report **never claims real-model or semantic success**. It ends as
  `CLIENT_EXERCISED_NOT_RELEASE_PASS`; the hosted XCTest remains skipped pending
  reconciliation. Missing opt-in is also explicitly skipped, not runtime PASS.
- Private Core/provider reconciliation rejects incomplete/zero-required-model,
  failed/reused provider receipts, wrong turn/answer, semantic/effect failure,
  mixed identity and overspent budget. Exact questions/model policies are checked
  against the pinned catalogue; the final gate rejects other catalogue versions
  even when their case IDs happen to match. `agent_calls`, latency or plausible prose
  never substitutes completed provider evidence.
- A selected subset can only be `PASS_SELECTED_SET`. The separate release gate
  requires coverage of **all 167** pinned cases on one app binary, Core installation
  and reviewed producer adapter. Missing/duplicate cases and mixed candidates fail.
  Zero-model-only families may pass their selected-set checks without forcing an
  unnecessary model call; the complete gate requires actual paid attempts across
  the matrix. Even its `PASS_CORE_CLIENT_GOLDEN` is not native gesture, physical audio or
  production release authorization.

## Current honest execution boundary

The native harness compiles; pure orchestration regressions run without credentials
or network. **No real model/native Session run is claimed by those tests.**
Core explicitly confirmed no qualified public native-consumer manifest, fixture
admission or provider-run export currently exists. The private `reconcile` input
format in `golden.py` is a **test-adapter handoff proposal**, not an existing Core
API/receipt contract. Core owns publication/qualification and the adapter's exact
source pin before a runtime result can be used for release acceptance. No guessed
endpoint or new Core source write is introduced here. A JSON field saying
`QUALIFIED` alone is not producer provenance; the operator must independently
verify the supplied adapter commit, installation and receipt origin.

The old Core laboratory records cannot be attached to a new native run: run ID,
client-message hash, exact server turn, answer hash and installation must all
match. Real attempt budgets are enforced by the qualified Core/provider lab;
Apple caps submissions and reserves the declared per-turn maximum, but cannot
control provider internal retries through a new invented API. A higher/unknown
Core ceiling is not admitted by this version. There is no use of Core's current
40-call research budget, WIP or credentials.

Some Core inventory steps describe special fixtures/context/provider actions,
not independently executable arbitrary chat prompts. The admitted Core fixture
must establish **each selected family's complete preconditions** first. Do not
send the whole catalogue into a personal Session and call it qualification.
Current source questions are Dutch. The initial adapter admits only an ordinary
Dutch client; proper five-language execution needs Core's qualified localized
consumer export. Merely changing a language field does not translate a Golden case.

## Prepare a release candidate run

1. Core supplies a reviewed exporter/fixture admission and exact installed source
   readback, disposable test Profile + active Session, actual configured model and
   bounded provider budget. Use a dedicated test output for music-effect families.
   Do not reset/erase the owner's Profile or personal history. Public research and
   real music side effects are tested only within that explicit fixture admission.
2. Verify the exact native app binary/build and normal pairing. Do not install a
   diagnostic bundle into an ordinary app or change entitlements/signing profiles
   implicitly. The existing macOS hosted-runner startup limitation remains open;
   compilation is not evidence that this host can launch a hosted runner. A real
   iPhone/iPad requires its existing signed developer/test-host arrangement.
3. Copy `context.example.json` to an owner-private directory, mode0600. Fill verified
   fingerprints/build and fixture admission. Preserve local speech preferences;
   with autoplay enabled the plan needs explicit `allow_audio:true` on the test
   output. Default is false and rejects active autoplay rather than resetting it.
   Optional `selected_entries` maps canonical step ID to the actual original
   `session_id`/`entry_id`; Core supplies qualified context. An absent typed source
   is not replaced by another current track.
4. List/select whole Core families, for example the informational four-step chain:

   ```sh
   python3 Tools/qualification/askdj-golden/golden.py inventory
   python3 Tools/qualification/askdj-golden/golden.py plan \
     --context /private/tmp/djc-golden/context.json \
     --family ASKDJ-FLOW-open-musical-wish \
     --output /private/tmp/djc-golden/plan.json
   ```

   Generation performs no network calls. Inspect the exact case/precondition/effect
   scope and budget, then deliberately set `execute:true` in that private plan.
   Plan and output paths contain no credentials. Never arm a whole catalogue from
   the illustrative template or infer fixture admission from the native code.
5. Use the separately generated, signed **hosted** `DJConnectAskDJGoldenHosted` target with environment
   `DJCONNECT_ASKDJ_GOLDEN_PLAN=<private plan>` and
   `DJCONNECT_ASKDJ_GOLDEN_OUTPUT=<private evidence directory>`, running only
   `AskDJGoldenIntegrationTests/testRealPairedSessionGolden`. The ordinary
   `DJConnectCoreTests` target is unhosted and cannot run the armed qualification.
   Use the separate `generate_hosted.py` overlay described below. `swift test` is for compile/
   unarmed-skip verification; an armed SPM runner fails the ordinary app bundle pin.
   Plan inputs are paths in the runner environment; no token, model key or private
   transcript is passed through process arguments. In a device run, stage private
   inputs/output through the approved test-host container; host paths are not
   silently assumed available on the iPhone.
6. Obtain the **same run's** independently qualified Core/provider export. Reconcile:

   ```sh
   python3 Tools/qualification/askdj-golden/golden.py reconcile \
     --native /private/tmp/djc-golden/RUN_ID/native-run.json \
     --producer /private/tmp/djc-golden/core-provider-run.json \
     --producer-commit EXACT_REVIEWED_EXPORTER_SHA \
     --output /private/tmp/djc-golden/verified-batch.json
   ```

   Every failed attempt counts. No automatic fallback model or rerun. Retain the
   original failure/uncertain receipt. Independent quality/effect review remains
   Core-owned and must use the actual correlated answer/provider readback, not
   literal prose matching or a second uncontrolled model judge.
7. Run remaining admitted families in separately bounded batches and preserve their
   individual run markers/receipts. Aggregate only same-candidate verified batches:

   ```sh
   python3 Tools/qualification/askdj-golden/golden.py release-gate \
     --receipt /private/tmp/djc-golden/verified-batch.json \
     --receipt /private/tmp/djc-golden/next-verified-batch.json \
     --output /private/tmp/djc-golden/release-gate.json
   ```

   A smoke subset remains partial. Missing producer evidence, skips, incomplete
   matrix, missing facts/art/queue effects and failed Core findings are failures or
   unresolved acceptance, never a successful release gate.

## Separate macOS hosted target

The explicit overlay keeps diagnostics out of the ordinary project and shipping
bundle. The helper stores its resolved spec in the private directory and generates an
ignored `DJConnectAskDJGolden.xcodeproj` beside the ordinary project. Source paths
keep the real checkout root; the ordinary Xcode project is not replaced:

```sh
mkdir -p /private/tmp/djc-golden-hosted
python3 Tools/qualification/askdj-golden/generate_hosted.py \
  --output /private/tmp/djc-golden-hosted
```

Use project `DJConnectAskDJGolden.xcodeproj`, scheme `AskDJGoldenHosted`, with
the already authorized signing/test-host setup.
`build-for-testing CODE_SIGNING_ALLOWED=NO` verifies compilation only. It cannot
establish runner launch, pairing, model or device acceptance and must not replace
the ordinary installed app. There is no entitlement/profile or ad-hoc signing
workaround in this slice. Core/provider admission remains necessary even when a
signed runner can launch. After signed `build-for-testing`, run the generated `.xctestrun` explicitly:

```sh
python3 Tools/qualification/askdj-golden/run_hosted.py \
  --xctestrun /private/tmp/DERIVED/Build/Products/AskDJGoldenHosted_macosx.xctestrun \
  --plan /private/tmp/djc-golden/plan.json \
  --output /private/tmp/djc-golden/results
```

Use the actual emitted `.xctestrun` filename. The helper writes a private copy,
preserves its test-product paths and injects only plan/output paths for the exact
hosted target. It invokes only this test, captures xcresult/logs privately, does
not alter signing/profiles, and never retries. Exit2 means client exercised but
Core/provider reconciliation is still required; exit0 is never a release PASS.
Never arm the ordinary PR/CI test scheme.

## Native proof boundaries

This first slice runs the **actual native application model/send/render/readback**,
including the actual bubble renderer, not XCUI pointer gestures. Chip taps, contribution tap hit-testing, deletion swipe,
menus, album-button taps, actual audible output, physical avatar animation and
visible viewport/screenshot acceptance remain separate native suites. Requesting
an album in this suite must still receive Core's actual full-context/effect verdict;
one track is not a whole album. Artist-photo pixels and Mood queue effects cannot
pass from response text alone. Core's newer album/photo/Mood/Tell-more WIP is not
imported or represented as delivered by this pinned catalogue.

## Offline verification

```sh
python3 -m unittest discover -s Tools/qualification/askdj-golden -p 'test_*.py'
swift test --filter AskDJGoldenIntegrationTests
```

The second command must SKIP with no plan. Ordinary CI runs only these no-paid-call
paths. No scheduled/PR/tag job receives a real model key or silently starts sessions.
Never publish xcresults, app logs, private context/export files or raw transcripts
as public artifacts; keep only independently redacted summaries.

Reproduce the immutable input catalogue without altering the admitted file:

```sh
python3 Tools/qualification/askdj-golden/import_catalog.py \
  --core-repo /path/to/core-checkout --output /private/tmp/reproduced-catalog.json
cmp Tools/qualification/askdj-golden/core-catalog.json /private/tmp/reproduced-catalog.json
```


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

## Manual Apple fixture CI

Run **Apple E2E fixtures** from GitHub Actions when checking Session UI and Ask DJ
changes across Apple targets. It runs iPhone and iPad simulator UI flows, macOS
UI smoke, Watch companion/Moment contract tests and a surface contract job for
pairing, notification consent and background state. Each job requires a minimum
number of passed tests and rejects skips. It uploads only fixture-run evidence.
The ordinary PR workflow continues to run the cheap contract and orchestration
checks.

This CI workflow does not arm a Golden plan. It uses the existing local demo
fixtures and Watch contract tests. A real Golden run still requires the qualified
Core producer handoff, supported host and provider evidence described above.

## Audit against the current Core inventory

With a local Core checkout, compare the hosted adapter to Core's 44 families
and 385 steps:

```sh
python3 Tools/qualification/askdj-golden/audit_core_catalog.py \
  --core-repo '/path/to/djconnect'
```

The audit checks the inventory at the local Core `origin/main` against the
reviewed digest. It reports missing cases, changed expectations, chain changes,
and language, route, or model-policy gaps per family. Exit 1 means there are
gaps or the inventory pin needs review. The audit performs no session or
provider calls and produces no execution receipt.

## Apple transport coverage for the exact Core catalogue

`goldenCatalogueOrdinaryAppleTransport` exercises the paired Apple HTTP client
with 70 original prompts and 30 continuation steps across EN, NL, DE, FR and ES.
The fixture checks locale, Session scope, opaque speaker-choice identity and
the unchanged request body when the duplicate probe resends an accepted turn.
It uses a synthetic HTTP responder. Core's two catalogue execution gates
remain separate and require actual Core answers, provider effects and variation
evidence. The test does not exercise native UI gestures.

Reproduce the test fixture from the pinned Core Git object with
`export_catalogue_transport.py --core-repo <core-checkout> --output <new-file>`.
Compare the output byte for byte with
`Tests/Fixtures/askdj-golden-catalogue-transport-v1.json`.
Run the Swift test explicitly with the `DJConnectMac` scheme and selector
`-only-testing:DJConnectCoreTests/goldenCatalogueOrdinaryAppleTransport(_:)`.

## Golden delta contract verification

Use `audit_core_catalog.py --execution-plan` to export the exact new and
changed steps alongside the old and new order of each affected family.
The report covers 218 additions and six revisions, including all eight
changed sequences. It is a planning input and leaves the historical
167-step hosted admission pin intact.

For producer-side regression verification, export the pinned Core Git
tree to an empty directory with `git archive`. In a Python environment
with that revision's development dependencies installed, run
`run_core_delta_contracts.py --core-snapshot <export> --output <new-directory>`.
The runner selects the named owning tests by exact file and method, fails
if any named test is absent, and records fixture outcomes by case.
It reports separately which cases still require live quality evidence.

On Apple, the manual workflow's `golden-contract` job runs the catalogue
transport and targeted album, Help, retained speech, contribution,
Mood, archive deletion and content deletion checks. The album fixture
contains the frozen result set emitted by Core's 50-track owner test.
Apple checks that the album and last track keep different actions and
that invalid or expired album layouts cannot supply frozen actions.
These checks qualify client contracts. Live model answers, provider
effects, physical audio and full native UI sequences need separate runs.

## Online catalogue UI suite on iPhone or iPad Simulator

Build `DJConnectIOS` in Debug for the iOS simulator with
`xcodebuild build-for-testing` and a new DerivedData directory. Install its
`DJConnect.app` on a dedicated simulator. Open the app normally, pair to the
authorized disposable HA-dev Profile, set the app language to Dutch, and open
the already active DJ Session. Keep a current track with an album, a confirmed
test output, and an available forecast. The fixture also needs an available
backend with queue, search, output, playlist and recent-history capabilities.
Use an isolated playback fixture or the currently confirmed Schuur output.
The play prompts can change playback. The suite does not tap additional
playback choices.

For a fresh Dutch simulator, the opt-in
`testPrepareOnlineCataloguePairing` UI test can handle the pending DJConnect
pairing-link prompt and local network onboarding. Run only that selector with
`DJCONNECT_ONLINE_PAIRING_SETUP=1` in the UI test target environment. Deliver
the fresh link through the normal pairing flow first. Finish the HA-dev
wizard with a separate Profile and complete its provider sign-in, then
confirm the actual Profile, Session and output before arming any online sends.

Create a mode-0600 JSON plan with these fields:

- `execute: true` and `fixture: "DISPOSABLE_ONLINE_SESSION"`.
- `session_id`, `profile_id` and `output_id` from the confirmed fixture.
- `artist` for the three Help actions that insert an editable artist slot.
- `reply_patterns`, a dictionary of 14 case-insensitive regular expressions
  keyed by the catalogue's entry IDs. Write each pattern for the fixture's
  expected answer or valid next step. For example, the current-track response
  can be checked against the fixture track title. Patterns must cover both the
  completed Help prompt and its rotating suggestion counterpart. Use the full
  `entries[].id` list from `ask_dj_examples_v1.json`.

Run the generated simulator `.xctestrun` with the dedicated simulator UUID:

```sh
python3 Tools/qualification/askdj-golden/run_online_simulator.py \
  --xctestrun "$DERIVED/Build/Products/<simulator-test-run>.xctestrun" \
  --plan "$PRIVATE_PLAN" --simulator "$SIMULATOR_UDID" --output "$NEW_PRIVATE_OUTPUT"
```

The suite opens each of the 14 Help actions through the active Session
composer and verifies draft completion for the three artist templates. It also
reopens compact suggestions until every catalogue ID has been tapped, checking
that each visit shows three distinct choices. Each send must produce a new
matching question and correlated server reply in the original Session, and
each reply must satisfy its expected pattern. Missing capability, stale or
changed scope, absent answer and incomplete rotation coverage fail the run.
The runner also rejects a skipped test. Keep the result bundle and logs private.
This UI suite does not establish audible playback or independent provider receipts.

## Regression coverage by layer

| Critical path | Fast unit and contract coverage | Integration and E2E evidence still required |
| --- | --- | --- |
| Pairing and recovery | Pairing URL and identity validation, credential storage, authenticated status confirmation and Watch proxy identity | Fresh paired simulator flow and signed Watch recovery after revocation |
| Session Flow and Ask DJ | Golden transport, ordering, playback and history fixtures, including stale responses and deletes | Existing simulator/macOS smoke exercises native session UI. Run ordered Golden scenarios against a qualified live session to establish model and provider outcomes. |
| Help and suggestions | Catalogue contract and runner checks | The manual online simulator suite exercises all 14 Help actions and all 14 suggestions with a pinned active session. It requires an authorized fixture. |
| WidgetKit and Live Activity | Manual `surface-contract` job exercises device/role consent, paired discovery, background credentials, expiry, and delayed artwork | Signed-device delivery after a real DJ publication on Mac, iPhone and iPad, plus artwork and track changes on the lock screen and Dynamic Island |
| Watch and app Moment alerts | Watch locator and retained Moment tests, and app navigation including revoked consent during a pending read | Loopback WebSocket suite exercises subscription, admission and withdrawal. Signed APNs receipt and opening the exact Moment on each target require device runs. |

Run the six loopback Moment integration tests using a macOS Debug
`build-for-testing` result and a Core checkout containing the pinned producer
commits. The runner starts and stops its own local server and requires all six
tests to pass without skips.

```sh
python3 Tools/qualification/run_moment_network_tests.py \
  --core "$CORE_CHECKOUT" --xctestrun "$MAC_XCTESTRUN" --output "$NEW_PRIVATE_OUTPUT"
```
