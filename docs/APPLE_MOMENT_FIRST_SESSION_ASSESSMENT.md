# Apple Moment-first Session assessment

Assignment: `DJC-APPLE-MOMENT-FIRST-SESSION-V1-20261008`.
Status: implementation WIP; no complete product/native qualification or merge.

## Scope and source pins

Both native Moment-first DJ Session and independent Speelt nu belong to this
one Apple slice. Apple base: `2fc7fdf173d9ddb9c309e5837f1c7a449e170be9`.
Original assessment pin: `ee05c9422cd7a7a08bbe769925248632fa651961`.
Current producer contract candidate: `3d17994d28c71402a9076c0082c490820204ccda`,
tree `18620004f02663cc0d263073142527b95581cffa`, draft Core #1128.
This is an exact producer candidate, not merged/installed HA.
Owner selection and ACK/STARTED are in [#87](https://github.com/pcvantol/djconnect-app/issues/87).
Core remains a separate source lane. This consumer does not write Core.

## Experience gap and implementation

The former iOS primary Speelt nu label opened a technical Session screen;
macOS retained a standalone player but had no native Session destination.
The shared decoder consumed only Session, Planner and Flow labels.

The Apple WIP separates DJ-sessie and Speelt nu, restores the existing iOS
player components from the pre-#48 route without reverting the root view,
and adds shared native current-Moment and committed Flow/detail presentation.
Current music is owner Broadcast context. The same model owns one live
subscription, snapshot/event sequence reduction, callback generation guards,
foreground recovery, background cancellation and confirmed end/unpair cleanup.
Navigation does not call start/end or playback mutation methods.
The primary iPad navigation keeps Meer visible while other tabs can scroll.

The Moment payload stays ephemeral in memory: no new disk cache, analytics,
export, history owner, Persona rewrite, local Planner or invented actions.
The owner subscription uses normal HA authentication plus paired DJConnect
identity; receiver grants and VibeCast web pages are not used.

## Pinned producer admission consumed

The initial [Apple gap](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6055967587)
and [Core gap](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6055968322)
are now addressed by the [exact producer receipt](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6059342828).
Apple decodes `native_delivery` v1 as replacement authority, separate from
Moment identity, text/Persona, Flow revision and event watermark. Current uses
the supplied current ID, playing/item binding, admission and original deadlines.
Earlier-only Flow uses ordered permitted IDs and original source expiry. Missing,
unknown or malformed authority cannot grant display. Attributed CC0 source cards
retain both recording URLs with native localized link labels. Spotify current-only
cards remain suppressed pending a qualified renderer mark/attribution asset;
this is an explicit Apple presentation finding, not a missing Core rights field.
The executable-action allowlist remains empty; existing player/Ask DJ/queue/handoff
routes retain their independent authority.

Background/disconnect clear both native authority and Moment/Presentation copies;
a fresh owner projection is required to resume. Expiry events replace admission
and prune withdrawn content, including open Flow detail. Terminal denial clears
before sequence filtering even without a sequence. Subscription withdrawal clears
that display channel without declaring the server Runtime ended; normal Session
end clears the whole Session. No individual source-revoke API is invented.

`Tools/generate_native_moment_receipt.py` executes the exact pin's existing producer
capture through an immutable archive; no mutable Core source is imported or
written. Synthetic recovery cursors are omitted. Its actual owner HTTP/subscription
snapshots/events cover credits, shared producer, source expiry, snapshot-required
reconnect and normal end. These remain software fixtures, not live provider,
installed HA or Mac native proof.

## Red scenarios and evidence boundaries

Required acceptance includes two distinct real producer-chain Moments during
one track, later events, track change, duplicate/stale rejection, reconnect,
background return, confirmed normal/failed end, unpair and Profile authority
change. Native iPhone and Mac must show correct copy/meaning/source links;
iPad adaptive layouts, long text, VoiceOver and Reduce Motion remain required.
Independent player navigation must work without, during and after a Session,
with no start/end/playback mutation and preserved other feature routes.

`Tools/generate_moment_contract_receipt.py` imports an immutable archive of the
pinned producer through its existing test dependency loader. Its synthetic,
nonpersonal Runtime/Planner/Knowledge/Moment/Broadcast receipts are explicitly
fixtures, not live provider or hardware proof. `Tools/moment_contract_server.js`
models owner HTTP/WebSocket envelopes on localhost, counts active subscriptions
and distinguishes read-only command requests from playback mutations.
Run it with an ignored receipt path and the explicit Core reference path; never
point it at a real HA instance. The opt-in network test requires
`DJCONNECT_MOMENT_NETWORK_TEST=1`; normal unit runs explicitly disable it.

The current isolated validation has 404 regular Swift cases passing and four
opt-in network privacy/authority cases passing separately. The latter prove
owner HTTP/WebSocket reconnect/end, rejected owner authority clearing private
projection without ending the Runtime, no parent URLCache storage under
explicitly cacheable headers, and omitted Moment response bodies in decode
errors. Delivery callbacks are awaited serially; optional new locale/Flow
fields fail independently and cannot discard the valid Session.

Native iPhone and iPad simulator tests completed successfully through the
actual decode/state/native route: first snapshot Moment, a second contribution
on the same track, background/foreground, standalone player, producer-observed
track change, reconnect, confirmed end, player after end, fresh app launch
without a Session and the player again. iPad additionally records portrait and
landscape. The track-change producer selects Silence; it is not emitted as a
visual Moment event. The native renderer shows the supplied committed Silence
Flow label and quiet current zone rather than manufacturing a Moment.
Navigation metrics record zero playback mutations. These are synthetic fixture
receipts, not live provider, physical device or full accessibility qualification.
Screenshot review additionally corrected duplicated primary speech for the
producer's actual `dj` role. The iPad test now waits for rotation to settle and
asserts Meer remains hittable in landscape; device-level screenshots avoid
XCTest's incorrect landscape application-bounds crop. English navigation tests
check Queue/Playlists/Now Playing under More, matching the actual route model.
The final screen-capture iPhone/iPad sequences both PASS with no runtime
warnings (`iphone-screen-qualified.xcresult`, `ipad-screen-qualified.xcresult`).
An earlier combined English/iPhone attempt hung and was interrupted without a
valid result bundle; it is not counted as PASS. The screenshot-helper compile
failure used `XCUIDevice` incorrectly and was repaired to `XCUIScreen` before
the successful final sequences. Logs remain retained separately.
The separate English navigation attempts also stalled without a finalized
result bundle, including with the existing ready fixture. English native
navigation is therefore NOT QUALIFIED; no success is inferred from compilation.

Unsigned Mac build-for-testing passes. The unsigned Mac UI runner hung before
establishing a connection. A direct isolated unsigned candidate receives owner
data but has not produced an accepted visible native window. Local ad-hoc test
signing and read-only independent review agents were requested; no answer or
new authority has been inferred. Full Mac native acceptance and the remaining
accessibility/locale/long-copy review remain open.

Primary macOS dataless source/index reads blocked verification. WIP was
preserved as a recovery patch plus all six new files and reintegrated in an
isolated temporary Apple clone by the same writer. The no-checkout Core clone
is an immutable archive source only, not a Core checkout or writer.

Draft [#95](https://github.com/pcvantol/djconnect-app/pull/95) preserves this
same source pickup. All non-skipped CI/TDE/security/projection checks passed at
`636258d8c93044004adb8fa31babed612def9d37`; those receipts do not qualify later
heads or resolve the product gates above. The Core producer now has its own
ACK under `DJC-CORE-NATIVE-MOMENT-DELIVERY-V1-20261008`; its unqualified WIP is
not substituted for the immutable producer receipt.
No source merge, exact-main acceptance, internal evidence publication or separate
Finalization is claimed. Those remain required after contract/native/independent
review gates pass, and each concrete main publication needs its own authority.
No Store/TestFlight/public release, signing certificate, physical installation,
Core/HA deployment or workflow/protection change belongs to this WIP.

## Native delivery candidate readback

Pinned receipt tests prove current/earlier CC0 display, two links, unchanged Persona,
original shared-source shortest deadline, presentation expiry separate from recall,
missing/unknown/schema/Spotify-attribution denial, event admission replacement,
source-text pruning and unsequenced terminal clearing. The broad concurrent run
failed with eight timing/fixture issues in three existing tests; the full serial
run passed 406 regular tests with four opt-in network skips (410 reported).

Latest native iPhone and iPad actual HTTP/WebSocket→state→SwiftUI sequences PASS
for admitted source cards/both links, background recovery, independent player,
source expiry/reconnect without revival, end and no-Session player. iPad includes
settled portrait/landscape and visible Meer. Source/Mac/physical/install acceptance
remain distinct; earlier Track Insight fixtures now decode but grant no native
card without v1 admission, as the producer contract requires.

The additional native open-Flow-detail/expiry attempt stalled without a valid
final bundle and is NOT QUALIFIED. It is retained as a separate UI test, not
counted as the successful current/list/navigation sequence. The renderer's
Spotify mark finding and Mac/English/accessibility/independent review remain
open. A new delayed-HTTP network scenario proves that a response requested
before background cannot repopulate authority afterward; request generations
and loading completion are guarded. The three final-pin contract/state/network
tests pass, including this late response and unsequenced terminal denial.
