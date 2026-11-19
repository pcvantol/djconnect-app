# VibeCast app-key sequencing — bounded source slice

The existing Apple lane consumes the released API interface
`djc-rendezvous/1-implementation.1` under the existing scanner assignment. Exact
producer source PR96/main `2dade83f338ae5f931856934ab0c23b6f6c66f05` and separate
Finalization PR97/main `661e5770eb5249b1b02bbdc2426ba7e575fc8881` are delivered;
[the exact producer receipt](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6272409413)
and the owning Apple87 handoff were read back before implementation.

Verified immutable inputs at Finalization main:

| Input | SHA-256 |
| --- | --- |
| implementation-contract-release-v1.json | 189e71aca07ac49cc6f7db225d3acb10a3a9fc357be02a9eaacb8f30a798c596 |
| IMPLEMENTATION_CONTRACT_RELEASE_V1.md | a3be2c5fd6ca95a5b57f7a3687512670ebaa97a332f2df96d5259bb6c7530cf5 |
| KEY_STATE_V1.md | 4516319d5635964f2175ad36e89266d80204573253c0cf2e5c83892254930cd2 |

## Resulting behavior

`RendezvousAppKeyOperations.shared` is one process-wide actor for the full
sign → submit operation, keyed by the exact opaque App Attest handle. Two scans
and management actions using that handle share a FIFO slot. Ownership remains
held through suspended signing, submission, response handling and operation
cleanup. Independent key handles can progress independently. Actor reentrancy
alone would not prevent a second assertion from overtaking a suspended first
submission (KEY_STATE_V1, counter/crash ordering).

A cancelled waiting action is removed without signing. Cancellation after slot
handoff is checked before invoking the operation. Cancellation of an active
operation remains cooperative: it cannot release the slot until that operation
actually returns or throws. Failure releases its slot without stranding later
waiters. No pending task, assertion, counter or key handle is persisted or logged.

This is a reusable source component compiled into the three native Core targets.
The shipping scanner/transport does not yet call it. It does not implement SDK
signing, enrollment, management recovery, action encoding, JOSE, QR scanning,
route selection or live activation. The old qualification-only flat parser and
per-submit harness have not been promoted into production.

The future caller must put the **entire** SDK sign and submission/retry-resolution
sequence inside the operation. It must revalidate the current paired HA owner,
exact saved action bytes, key state and original deadlines **after acquiring**
the slot and around its own async boundaries. Enqueueing never refreshes a
transaction, challenge or key deadline. Unknown transport outcomes and immutable
retry receipts remain the operation's responsibility; this component cannot
promise remote work has stopped when a transport returns an error. Widgets or
other processes must not independently use the same key; no cross-process lock
or authority is inferred here.

## Qualification and limits

Focused deterministic tests exercise two-screen/management ordering across the
complete submission suspension, cancelled waiters, cancellation of an owner whose
submission does not stop, independent keys, error recovery, empty handles and
already-cancelled callers. Test-only isolated actors are internal; public callers
use the shared actor. Queue-count barriers schedule races without wall-clock
sleep assertions. Logs are under ignored
`build/qualification/vibecast-key-sequencing/`.

This is source/concurrency qualification, **not** genuine App Attest, an
API-owned challenge, actual API enrollment/submission, physical TV or installed
scanner proof. The producer has not released a qualified live rendezvous target.
No key was generated, no App Attest assertion or server request was made by this
slice, and no signing/environment/HA/service settings or ordinary installed apps
were changed. Installed Macs remain ordinary40370. A first default-build-system
Swift test attempt failed on pre-existing Finder metadata in `.build/out`; the
native SwiftPM scratch run avoids modifying that older build tree.
