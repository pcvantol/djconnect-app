# Apple Moment-first Session assessment

Assignment: `DJC-APPLE-MOMENT-FIRST-SESSION-V1-20261008`.
Status: implementation WIP; no complete product/native qualification or merge.

## Scope and source pins

Both native Moment-first DJ Session and independent Speelt nu belong to this
one Apple slice. Apple base: `2fc7fdf173d9ddb9c309e5837f1c7a449e170be9`.
Producer assessment/receipt pin: `ee05c9422cd7a7a08bbe769925248632fa651961`.
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

## Precise producer admission still open

See [Apple gap](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6055967587)
and [Core gap](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6055968322).
The pinned projection has no authoritative source fact expiry/revocation or
native active-Flow historical-display allowance. The qualified source contract
limits VibeCast visual source cards, expires facts after 30 minutes and does
not qualify historical display. Semantic Moment actions have no established
consumer execution endpoint/capability contract. Do not infer these rights
from an owner-authorized array, receiver grant or old release consent.

Until the producer owner resolves these exact conditions, attributed/source
cards and unqualified semantic action execution stay suppressed. This is a
blocking admission limitation, not completed Moment-first product delivery.

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
same source pickup. Its initial head CI/TDE/security checks passed; those
receipts do not qualify later heads or resolve the product gates above.
No source merge, exact-main acceptance, internal evidence publication or separate
Finalization is claimed. Those remain required after contract/native/independent
review gates pass, and each concrete main publication needs its own authority.
No Store/TestFlight/public release, signing certificate, physical installation,
Core/HA deployment or workflow/protection change belongs to this WIP.
