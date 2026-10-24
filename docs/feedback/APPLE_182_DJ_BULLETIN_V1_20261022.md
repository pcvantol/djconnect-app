# Apple #182 — DJ Bulletin V1 consumer preparation

Source WIP on existing sole-writer branch `codex/apple-avatar-focus-ring`, verified main/base `8c349e7581a13c7700643df0fcf14366feb9e0ae`. Earlier WIP is preserved. No Core source mutation, new writer, installed feature, merge or deployment is claimed.

## Producer binding

Core provided its uncommitted preparatory `examples/client_contracts/dj_bulletin_v1/actual-ha-wire.json`, SHA256 `909f525e609af7daf07653099a1c34b688cfd1e171b75d24c9225e34fceccc2f`. The checked-in test fixture is byte-identical, retaining its actual isolated-HA receipt/harness/source hashes and declared synthetic external boundaries. It is not an operative protected producer pin. Core reports the final committed handoff remains pending.

## Minimal consumer

- Recognize additive `dj_bulletin` with string `generation_metadata.bulletin_schema` 1 and exact owner-only/fixed-RSS metadata shape. This is wire validation, not client news collection, freshness decisions or scheduling. Unknown versions/types remain non-executable and cannot inherit music-source admission. Other Moment decoding remains compatible.
- Respect existing explicit native delivery qualification, owner Session identity, current/Flow flags and original source/display deadlines. Existing music-family attribution gates are unchanged.
- Reuse `MomentCard`: small newspaper glyph and localized static type label in NL/EN/DE/FR/ES, unchanged Core narration/Mood/Persona, HTTPS source attribution links. No news screen, settings, categories, cache or new voice player.
- Current bubble and live Flow share stable publication identity. After the short current-display admission ends, an explicitly admitted live Flow item may remain until its original source expiry. Merge this ephemeral item chronologically with existing rows; omit duplicate current/history copies. Retention is never fabricated.
- Existing client autoplay toggle/voice/output/foreground policy remains owning. New live Bulletin requires the current native Moment for automatic speech; manual replay may use its explicitly admitted live Flow source. Recheck admission while queued and during existing speech preparation/playback. Revoked or removed pending IDs cannot reappear as late speech after ABA/reconnect.
- No Watch feature expansion: existing companion projection and speech request refuse this family; unknown-type decoding remains compatible. No widget/notification/VibeCast/receiver changes or RSS/model/HTTP news request.

## Evidence

Non-mutating canonical-root host verification passed (onboarding4.5.4, MATCH, exit0). Initial default-root read was a false path mismatch and is retained.

`/private/tmp/djc-apple-night-20261022/full-lane-tests-first.log`: **1,164 tests in24 suites PASS121.521s**, serial. Explicit opt-in network/native tests remain skipped, not passed. Localization validation:1,447 keys/5languages PASS. Initial large SwiftUI typecheck timeout, helper-extraction syntax failure and inaccessible private foreground flag compile failures are retained; corrected by typed row helper and scene-owned lifecycle.

Native view-only qualification passed through `Tools/qualification/dj-bulletin/`: existing MomentCard, original fixture, no AppModel/pairing/HTTP/SDK/audio effects. Each platform exercised20 variants (5locales × dark/light × standard/accessibility text), in one XCTest function. Mac `bulletin-native-mac-window.xcresult`, ordinary iPhone17Pro `bulletin-native-compact-iphone.xcresult` and iPadPro13 `bulletin-native-ipad.xcresult` all report TEST SUCCEEDED. An earlier iPhoneDuo run also passed but does not substitute for the ordinary iPhone. Mac capture now targets only the test window; earlier full-desktop captures remain private and must not be published. Representative screenshots have been visually inspected; actual VoiceOver speech, production lifecycle and audible autoplay are not qualified by this renderer host. Initial query/identifier failures are retained with their corrected reruns.

WIP hashes and preserved review copies: `/private/tmp/djc-apple-night-20261022/bulletin-source-review-manifest.json` and `bulletin-source-review/`. This is a local review snapshot, not a Git pin, build provenance or release grant.

## Still open

Exact protected Core producer/fixture join and independent consumer review; complete production accessibility acceptance; actual paired Core publication and physical speech/output acceptance; protected Apple source/CI/review/delivery. Whole issue182 remains open until its complete acceptance is satisfied.

## Later source compatibility and bounded review

Core personally verified the original16-file immutable manifest `5acb12c133ec4266efe00b980e637d07343084b673cc587611b69de1aae15bf9` and returned bounded contract `NO_BLOCKERS`; private audit `apple-bulletin-root-bounded-contract-review.json` in its existing evidence directory. This applies only to the preparatory source slice and supplies no whole-app or operational admission.

Core then committed its coherent preparation to draftPR1293 at `3b4589347f61863ecad483e2d60f4deb6b8f7998`. Apple independently read its exact `actual-ha-wire.json` Git blob and matched SHA `aac3b59b6ecce6d7d3a1ca979db6edc08cad4376268c0806d88e06a78ff900b9`. Imported as `dj-bulletin-v1-core-3b458934-wire.json`; it is now the main software-regression fixture, while909f remains preserved historical compatibility evidence. All11 Bulletin test functions pass on the new source fixture. One chronological test initially used a historical absolute later-time constant; it now derives later time from each original fixture timestamp. No product chronology change was required. Both fixtures declare native NOT_RUN. The producer is still a source-preparation draft; operative producer pin remains null.


## Whole-candidate review correction — original live deadlines

Core's independent whole-PR183 review of3eef742 found a P2 outside the earlier
bounded Bulletin review: the parent Flow schedule included retained entry/media
deadlines only. With no retained rows or incoming update, a live Bulletin could
remain mounted until the next minute after its original source expiry.
`SessionTimelineLiveRow.refreshDeadlines` now joins original native source and
display deadlines with the existing retained deadlines at the actual TimelineView
callsite. It schedules local invalidation only; no source request, renewal or
new retention. The quiet/no-retained-row causal regression is RED with the old
retained-only join (one failure), GREEN with the original display/source equality
ticks. Fourteen adjacent Bulletin/schedule functions pass0.195s. This closes the
identified timing path in source; whole-candidate review and native/runtime
qualification remain separate.

## Client continuation — protected producer and accessible sources (2026-10-23)

This section supersedes earlier preparatory-pin statements for the current
consumer tests only. Protected Apple base is
`027354f31e1a3e46f726e2bd65ba1099947c9767`; the sole-writer continuation is
`codex/apple-bulletin-client-qualification`. Unrelated widget first-read work
remains preserved separately in draft PR185.

The main software fixture and disposable native host now use
`dj-bulletin-v1-core-12675bc-wire.json`, independently matched against
`examples/client_contracts/dj_bulletin_v1/actual-ha-wire.json` at protected Core
`736378991f6ce54b9565f11314acf5863d3eb58b`:
SHA256 `1f6ae4e9ec314a2dc60ffcdf7d66497795baf840952b5897c09cfeb98d27eeee`.
Historical preparatory fixtures remain covered by compatibility tests.
The initial fixture-switch run failed only because its checksum assertion still
named the older fixture; the exact updated pin passes all 17 targeted tests.

Bulletin attribution links retain their original provider/license and destination.
Their accessible name also contains the supplied story title so two links from
one publisher can be distinguished. No headline is generated or translated by
Apple, and ordinary music attribution keeps its existing fallback.

The disposable native lifecycle probe uses the real production admission,
chronological row merge and MomentCard, with a controlled fixture clock. It
checks exactly one current bubble, exactly one Flow bubble at the original
display deadline, and no bubble at the original source expiry or after authority
withdrawal, across all five locales. It does not instantiate AppModel, make HTTP
requests, pair a profile, publish a Moment or produce audio.

Canonical host verification: MATCH, exit 0. Full serial package suite:
1,212 Swift Testing cases in 24 suites PASS (133.704s), plus 86 XCTest cases
with five explicit skips and zero failures. Evidence logs and isolated projects
are under `/private/tmp/apple-bulletin-client-{tests-r2,full-tests,mac,ios,ipad}-20261023*`.

No ordinary installation build, version bump, physical installation, new server
contract, private RSS client, new UI surface or additional speech player.
Paired Planner publication and actual audible/output acceptance remain NOT_RUN.

Native iPhone 17 Pro/iOS 27 qualification: both selected XCTest functions PASS.
The lifecycle test covers five locales (85.509s); the renderer test covers all
20 locale/appearance/text-size combinations (132.668s). Representative Dutch
normal/dark and accessibility/light screenshots were visually inspected.
Actual VoiceOver audio output remains untested; accessibility names are asserted
through the native accessibility tree.

The current Mac host compiled, but its UI runner could not enable automation
(`Timed out while enabling automation mode`). Developer mode was already enabled.
This run is failed/unqualified, not covered by the earlier renderer receipts.
The first dedicated iPad compile ran out of local disk; only this continuation's
Mac/iPad disposable derived intermediates were deleted, with logs and result
bundles retained. The iPad rerun reuses the exact successful iOS test products
via `test-without-building`.

The iPad Pro 13/iOS 27 rerun finished with exit 0 and
`TEST EXECUTE SUCCEEDED`: lifecycle five locales PASS (88.313s), renderer
20 variants PASS (112.658s), two XCTest functions, zero failures. Xcode's
optional post-test `simctl diagnose` collection stalled after the tests; only
that exact owned diagnostic subprocess was terminated, then Xcode finalized its
result bundle successfully. The termination receipt and final bundle are
retained. A representative Dutch iPad screenshot was visually inspected.

Completed log copies with SHA256 readback are preserved in
`/Volumes/Shared Data/tmp/pcvantol/apple-bulletin-client-20261023/`. Native result
bundles remain in the corresponding private temporary qualification directories.
Current Mac UI qualification, actual VoiceOver speech and paired Planner/audio
acceptance remain open; none is inferred from these fixture tests.
