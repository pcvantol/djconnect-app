# Saved session deletion — 18 October 2026

Owner request: expose search directly in the opened archive toolbar; add a red trash button at the trailing edge to delete that specific archived session from the owner's Profile after confirmation.

## Boundaries

Core owns durable deletion, access checks, lifecycle validation, revocation and contract documentation. Apple must not fake deletion by hiding a row or clearing device-local state. The existing Core writer has been asked to publish the canonical API contract and SYNC_PROMPTS changes first. Core has now published its selected delete-v1 contract in the canonical addendum; no installed producer qualification is implied.

Only an explicitly advertised, supported deletion capability may enable deletion. Active/opening sessions are excluded. The confirmation identifies one session and captures the current owner epoch. A rejected or ambiguous request keeps the archive visible and reports a localized failure; it is never automatically replayed. Only an admitted server acknowledgement permits dismissal. Owner changes fence completion, and stale reads must not resurrect removed projections. Successful deletion invalidates list/detail/search/open targets, cursors and presentation leases; fresh reads remain backend-authorized.

## Current state

- Archived session search now appears directly in the leading toolbar on iPhone, matching iPad/macOS, without a More menu.
- Five-language confirmation/action/failure copy prepared.
- Selected producer contract received: capability `session_history_delete:1`; confirmed POST to `/api/djconnect/v1/session/history/delete` with exact opaque revision and fresh operation UUID.
- Consumer DTO/client, capability gate, trailing red trash action and native confirmation wired. Matching owner/operation/target/epoch is required before dismissal. Active sessions excluded; unknown outcomes and failures are not replayed and retain projections.
- Successful acknowledgement fences in-flight callbacks, removes only the deleted target projections, stops deleted-source replay and refreshes through existing reads. Pairing, preferences, playback and other retained session projections are preserved.
- Consumer validation passed: 5 tests covering 22 cases, including 4 toast cases and the native demo model; explicit API owner-check strengthening also passed. The final UI-only navigation-generation guard compiled and the same 22 cases passed again. Native visual/gesture execution was not performed. Producer fixtures/qualification and native confirmation inspection remain pending. No integrated deletion completion or installed delivery claimed.
- Existing unrelated WIP and recovery copies preserved. No personal session has been deleted for qualification.

## Required qualification

Synthetic producer tests: owner isolation, wrong-owner hiding, active-session rejection, repeated deletion, storage-failure atomicity, stale cursor/deeplink and speech/media revocation. Consumer tests: exact request/response identity, no mutation replay, capability gating, cancel, stale confirmation, owner epoch change and racing reads, success dismissal, failure preservation. Native UI confirmation inspection remains separate from contract tests.

## Saved-session toast removed

Owner requested removal of the saved-session toast because the end-session confirmation now explains profile retention. Both ordinary and demo End paths no longer emit it. The archive lookup that served only the toast was also removed. Existing end failure/reset/no-replay checks and demo archival behavior passed; the confirmation explanation remains. No device installation for these follow-ups.

## Additional owner request: delete every earlier session

The list screen must show a red trash action immediately to the right of search, with confirmation explicitly covering all earlier sessions in the Profile, including sessions outside any active search filter or loaded page. The active/opening Session is preserved. This requires a separate backend bulk capability/atomic operation and an owner/snapshot-bound acknowledgement; never a client loop over individually loaded rows or a general Profile clear. Core has been asked to publish the canonical wire decision before client transport work.

The selected bulk contract is now canonical: capability `session_history_bulk_delete:1`, owner-only GET `session/history/delete_snapshot`, then one explicitly confirmed POST `session/history/delete_all` with that exact token and a new UUIDv7. The client verifies owner, operation, token, schema and exact captured count. Empty snapshots never offer confirmation or send a POST. Expired or changed snapshots require a new deliberate confirmation.

The list toolbar now groups search and the red trash action, in that order. The native popup renders the server count in all five languages. The action is hidden without the supported capability. Confirmation is discarded on owner/archive epoch change or navigation; a late completion cannot dismiss a different screen. Active/after-snapshot sessions are preserved by the server-selected set, not inferred from loaded rows.

On acknowledgement the client invalidates archive projections/navigation/cursors, uses separate archive generations to fence old reads, and reloads through owner reads. Active conversation epoch, current Flow and live speech leases are preserved. Old historical matches returned with a delayed active answer are filtered, while its active answer can still complete. No local Profile clear or per-row delete loop exists.

Consumer qualification passed: 8 tests / 43 cases covering single and bulk delete plus toast removal, including both held-callback races. Native code compiled for the host, and five-language validation passed for 1302 keys. The full existing Swift suite passed: 834 tests / 10 suites in 91.717 seconds. Producer fixtures/exact qualified pin, native visual inspection and installed activation remain pending. No personal session has been deleted.

Bulk preparation verification: the native confirmation control compiled and the existing single-delete regression matrix passed (3 tests / 17 cases) after extracting shared target invalidation. Five-language validation passed for 1302 keys. The producer clarified UUIDv7 for single-delete; the client now uses the existing UUIDv7 generator and rejects other versions. That refinement passed in the subsequent 43-case consumer run. No native/installed bulk completion is claimed. The closed preparation build products were archived locally before cleaning only that regenerable Swift cache; source and test logs remain.

Final consumer source validation: full Swift suite834/10PASS91.717s; eight focused tests/43casesPASS; localizations1302keys/fivelanguagesPASS; diff hygienePASS. Producer/physical/installed qualification remains separate and pending; installed40334 does not contain these follow-ups.

## Ordinary build40335 installation

Signed ordinary iOS (including Watch/widget) and macOS builds succeeded. Build40335 was installed and opened on the available iPad, MacBook and Mac mini; device/application readback confirmed40335, with no test bundle in the Mac app and previous Mac apps preserved. Pairing/Profile data was retained. iPhone and Watch were unavailable and remain last confirmed40331. The deletion consumer is included but both deletion actions remain hidden because Core has not implemented/qualified the selected producer capabilities. No personal session was deleted. Current native UI checks are tracked separately; no new physical visual or album-transition acceptance is inferred from installation. USB scroll profiling remains explicitly deferred until tomorrow. Follow-up source is not protected-delivered.

The bounded local Mac native UI run could build/sign its test runner, but XCTest timed out enabling automation mode before either selected test could execute screen actions. The own test processes were stopped; this is an environment limitation, not a product PASS or reproduced UI failure. Ordinary40335 applications were retained. The separate manual computer-use kernel remains unavailable because of its symlinked writable-root configuration. Native visual acceptance of tint, side-by-side confirmation and the DJ-session image transition remains open.

Core follow-up: Draft1197 source/contract pin `a5840acdffa99a8c1180d90b714c3c0fb9d983c2` retains the selected deletion contracts; this is not an installed producer pin. Producer code/fixtures remain absent and capabilities remain off.

Final packaging hygiene caught a retained historical app-hosted qualification bundle in the reused iOS product directory. That product was preserved, the ordinary iOS app product regenerated from the ordinary project, and the replacement verified to contain zero `.xctest` bundles with a valid signature before reinstall. This does not qualify the unexecuted UI checks.
