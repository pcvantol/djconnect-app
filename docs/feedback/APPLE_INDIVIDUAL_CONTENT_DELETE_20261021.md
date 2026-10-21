# Individual DJ Moment and Ask DJ contribution deletion

Peter explicitly requested contextmenu/swipe deletion for a single DJ Moment or
Ask DJ bubble, alongside trash on each earlier-session row. The latter is already
preserved separately in local `418a9ff`; this increment starts there and remains
local. No Apple installation or external publication occurred.

## Protected producer intake

Core source1253 `58561f97a04c36fce21ba5e6886eb6c3640a4ec3`, reviewed
`d53ab7f7c0dd0d025fe8da3858672fa398c19858`, separate Final1254
`b4bf47018d165e4f9e171291425a7a134ca9e0d2`. Owning Core handed canonical
qualifications39591327915/39593182742. Apple independently read the immutable source
contract and fixture from that source commit. Imported fixture SHA256
`7c062c4a5b944f3abfb5a8d419a1c5403eeaa842636f83c78821c1b979b3159c`.
No earlier f49 candidate was adopted.

Apple also read and preserved the producer's actual installed receipt:
232 matching source/Final files, payload90766c59519934c4c960ca7599fce24bc2491714f0aaf2b409591066e8c32805,
schema12/integrityOK/zero pending intents, six startup completions, config PASS and
runtime content-delete v1 capability. Receipt SHA256
`e1486de1fbe5a908866ab0ca69641b39da8f4ac906415c498dbd90d804b79356`.
This is independent receipt readback, not an Apple authenticated live deletion,
native/physical/audio acceptance or personal erasure test. Initial Core schema11
readback failure and unproven transient cause remain in that receipt.

## Behavior

- Earlier-session trash prepares fresh detail and confirms the whole Session.
  Its row control remains separate from opening the Session.
- Session entry, current Moment and accepted/uncertain Ask DJ bubble presentation
  have a destructive context action and horizontal swipe reveal. Existing bubble
  text contextmenus also receive the action. LazyVStack/ScrollView uses a horizontal
  drag reveal rather than nonfunctional List-only `swipeActions`; vertical drags
  do not select deletion. Swiping reveals trash and does not itself delete.
- Exact `entry_id`, Moment ID, server message ID or original pending
  `client_message_id` is used. Standalone messages explicitly send `session_id:""`;
  a Session is never guessed. Local presentation UUIDs/text/row adjacency are not
  deletion identities. An accepted bubble resolves the server's full exchange.
- A read-only prepare POST precedes the native confirmation. The dialog displays
  the resolved unit, exact server counts for removed/unavailable entries/messages,
  Moments and fenced requests, expiry, and preservation of Session/playback.
  Dismount, changed target/epoch, expired preview or lost owner fence confirmation.
- Flat paired identity, contract_version1 and existing Bearer are used. The strict
  producer allowlist is respected: no generic nested identity/device_name/profile
  additions. All prepare/delete/status responses bypass local caches/no-referrer.
- The original confirmed body and prepared identifier scope are synchronized and
  read back before POST in a bounded32-record/262144-byte local journal. It stores
  identifiers and hashed authority bindings, not conversation text or credentials.
  Single/bulk/content mutation admission is blocked on unresolved current-scope
  records, including after reconstruction or strict binding changes.
- Exact owner/unit/confirmation/operation/request_digest/entry and message arrays
  bind completion. The actual completed wire omits `affected_moments`; these are
  taken only from the original confirmation-bound prepared scope after receipt
  admission. No invented optional receipt field is required.
- Completed erasure withdraws related message/media/action grants and history
  epochs, suppresses withdrawn current Moment presentation without promoting an
  older Moment, then reads fresh authoritative projections. The journal clears
  only after qualified readback. Independent retained rows are restored. Unrelated
  pending turns/voice capture block this epoch transition; the composer cannot
  introduce a new turn during it and retains an unsent draft.
- Unknown/pending/expired/wrong receipts never optimistically erase or mint a new
  operation. The visible pending notice offers explicit GET status on the original
  body/ID. Only bound completed status plus fresh reads settles it; status errors
  never clear prior ambiguity. No automatic POST replay or renewal.

New user-facing copy is translated EN/NL/DE/FR/ES. Existing archive-status recovery
is not silently routed through content/status: its old single/bulk journals remain
blocked until separate archive recovery adoption. Changed authority may also keep
an original content record blocked; it never becomes permission for a new ID.

## Qualification

Final complete Mac run: **9 functions /50 cases PASS, 0 failures, 1.158s**. Includes
exact fixture hash, preparation owner/target/unit/expiry bounds, wrong completion
bindings/cascade, original Moment and request-cancel scopes, exact capability
version, closed flat request allowlists, success+fresh independent readback,503,
wrong receipt,409, in-flight owner withdrawal, no new composer send during that
fence, reconstruction, changed binding, readonly completed/pending/unknown/expired
status, corrupt/oversized archive/content journals, and existing archive fresh-read
and no-new-ID regressions. Synthetic cases rebase only confirmation clocks; the
model regression rebinds an independent existing timeline's Session ID for admitted
readback. Those adaptations are explicit test envelopes, not new producer facts.

Unsigned isolated iOS build-for-testing **PASS**, including new Core/UI source
files. Localization **PASS1387 keys/five locales**. `git diff --check` PASS.
Canonical XcodeGen project regenerated to register both production files and the
new/previously added local tests. Semantic before/after audit confirms existing
targets/settings unchanged, no removed objects and only additive source/group
membership. Initial sandbox generation failed on a temporary-directory permission;
the authorized generation completed and the original project is preserved privately.
This registration audit is not a full shipping app/Watch archive build claim.

Two actual offscreen Mac pending/status notice renders at430/320pt were inspected
with full wrapped text and visible status label. Final images are byte-identical
to the inspected preceding run. The supplied existing entry falls back to its
unavailable presentation in this host; this is not accepted-bubble visual proof.
Public AppKit status-button bridge count is0: **native activation INCONCLUSIVE**;
no fake click or fallback invocation was counted. Model status actions are tested
separately. Physical contextmenu/swipe/confirmation taps, iOS runtime and VoiceOver
remain unqualified. No claim of ordinary full-root/installed Apple acceptance.

Earlier preserved runs: test compile failed on nested Testing macro and non-Sendable
fixture capture (test code corrected); first complete wire run found the local
receipt decoder incorrectly required absent affected_moments (13 issues, fixed
against unchanged producer bytes). Subsequent scoped runs passed. No negative
binary preservation or warning-free result is claimed. SwiftPM/dependency/cache
and existing test warnings remain in logs. No live personal erase/provider/model
call, app install, simulator boot or night timer restart. Both build jobs complete;
own native windows/defaults close and unrelated work is preserved.

Private prefix `/private/tmp/djc-individual-content-delete-20261021*` contains all
logs, generated isolated project and producer receipt; native images/observations
are under the matching directory. Companion JSON records exact hashes for source,
fixture and evidence. Same-ID automatic replay is deliberately absent. Actual
cross-process/power-loss durability, server-side physical erasure, multi-device
acceptance and independent review remain separate gates.
