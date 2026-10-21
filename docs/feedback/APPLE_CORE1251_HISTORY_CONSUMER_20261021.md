# Core1251 history-deletion consumer assessment

Follow-up: Core's version answer has been independently checked on protected
source. Version is optional (omission1, explicit1/2); it does not change the
opaque deletion token. The first consumer delta is implemented and qualified in
[the fresh-confirmation receipt](APPLE_FRESH_DELETE_CONFIRMATION_20261021.md).
Pending operation retention and exact new wirefixture qualification remain open.

Assessment requested through the current Core writer after Peter's direct
instruction to coordinate client implementation across lanes. The human message
was independently read back in Core thread
`01a15af5-fe41-76a3-a35f-c87dcc1a8f16` before replying there. No second writer,
external issue/PR publication or product acceptance is implied.

Apple source inspected: clean `255b559`. Core producer source inspected at
`bbb7a23da015de5887eff4103efed9981f12b0bd`, its history contract and actual
synthetic archive-deletion-v1-20261021 wire fixture. Core explicitly reports
postmerge qualification, separate Finalization and HA-dev installation pending.
No operative installed producer or live client acceptance is claimed.

Existing Apple adoption includes single/bulk v1 capability negotiation, the
three named endpoints, UUIDv7 requests and confirmed:true, owner/epoch/revision/
snapshot-bound receipts, server-complete snapshot UI and no automatic mutation
replay. Local archive/media/speech presentation is invalidated after admitted
receipts. No individual-Moment/exchange deletion is inferred from this contract.

Concrete next consumer work identified from source, without runtime defect claims:

1. Single-delete confirmation currently captures the loaded timeline/detail
   revision. The model can fall back to a saved list session. Require a fresh
   authorized detail read before confirmation; never reconstruct the opaque
   deletion revision from the integer list-sync revision.
2. Ambiguous mutation outcomes currently collapse to false. Single action and
   bulk operation IDs are local to the call. Retain the exact original operation
   and inputs for explicit pending/unknown presentation and deliberate same-ID
   reconciliation within the original journal lifetime. Do not automatically
   replay or silently mint a new operation after an ambiguous result.
3. Adopt the exact producer fixture and add bounded offline wire/model coverage
   for pending503, same-operation recovery, conflict, detail-v2 and full snapshot
   semantics before live qualification. Existing synthetic tests are not proof
   of compatibility with this newly supplied producer receipt.

Open contract question sent to Core: the actual fixture's single_request contains
history_contract_version:2, but the normative delete-POST example omits it.
Apple's current delete payload omits that field while detail/open reads negotiate
v2. Core must clarify whether the delete POST must carry the detail version and
whether omission is rejected for a v2 opaque revision. Do not guess the answer.

No new endpoint, pairing operation, deletion, provider call, device installation
or unchanged green-test rerun. Recent Apple UI WIP, earlier local branches and
the paused expired night automation remain preserved. Consumer source work can
be qualified offline; live claims wait for exact Core Finalization/install proof.

Local copies read:

- `/private/tmp/djc-core1251-history-contract.md`
- `/private/tmp/djc-core1251-archive-deletion.json`

Coordination reply was delivered only to the authorized current Core thread.
