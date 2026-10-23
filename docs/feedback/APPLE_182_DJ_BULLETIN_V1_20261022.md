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
