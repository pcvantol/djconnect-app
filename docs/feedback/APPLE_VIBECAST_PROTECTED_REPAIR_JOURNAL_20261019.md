# VibeCast protected paused-recovery journal

This bounded source slice follows PR147 using API's released
`djc-rendezvous/1-implementation.1` contract, Finalization main
`661e5770eb5249b1b02bbdc2426ba7e575fc8881`. The pinned enrollment-recovery document
was rechecked at SHA256
`851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`.
It implements actual protected persistence for **paused same-key recovery
accounting**, not a full enrollment journal or working scanner.

## Persistence and admission

`RendezvousRepairJournal.shared` is the sole public production instance. Its
internal store uses one fixed generic-password Keychain address; opaque handle,
original pause window, attempts, reservations and server delays live only in
the encoded value. There is no Profile/Session/HA data, ordinary preferences
fallback, synchronization or public delete/reset/namespace override.

The item uses
[WhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)
and explicitly disables synchronization. macOS explicitly selects the
[data-protection Keychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain).
An LAContext with interactionNotAllowed prevents an automatic authentication
prompt. Read validates returned protection metadata. Only item-not-found means
absence; entitlement/lock/access/read errors and malformed/oversized data stop
work. The journal caps its encoded value at16KiB and validates the window's
schema/timeline on every load. Existing UserDefaults token storage is not reused.

Read/mutate/write operations are synchronous inside the shared actor; there is
no actor suspension between them. Updates use SecItemUpdate, with SecItemAdd
only when absent, never delete-then-replace. A duplicate insertion is an error,
not permission to overwrite another writer. This is a single-process writer
boundary, **not cross-process compare-and-swap or distributed locking**.

A reservation is returned only after its write succeeds. A failed write returns
no permission for external work. If storage committed but its result was lost,
the next read retains the in-flight reservation and refuses replay. Failed
completion storage leaves the prior reservation; uncertain outcomes must be
reconciled rather than refunded. Re-entering pause preserves the existing ledger,
including after expiry/success, and a different key cannot overwrite it. Full
key-lifecycle transitions are still required before a later legitimate repair
window/replacement can be admitted; callers cannot reset this store per scan.

## Actual native storage qualification

Tools/qualification/vibecast-repair-journal contains a reproducible probe that
compiles the actual production store/journal/window. It accepts only a synthetic
`dev.djconnect.qualification.repair.<UUID>` service and fixed test account.
No actual App Attest handle, assertion, challenge, HA token or network is used.

On the Mac mini, a scratch app bundle was signed using the existing development
identity and a copy of the existing valid profile/application-identifier
entitlements. No signing settings/profile/account were created or modified;
the ordinary app was not changed, launched or installed by the probe. Direct
execution avoided app registration and UI/audio actions.

Five separate process invocations passed: persist a synthetic reservation;
read back actual protection/non-sync metadata; restore the first in-flight fence
and reserve the second after completion; restore/exhaust the second without a
refilled budget; delete only the exact synthetic item and verify absence. Two
additional negative invocations rejected the production namespace and a malformed
test namespace before any Keychain operation. Cleanup succeeded.

The earlier unsigned probe returned missing entitlement(-34018), correctly
without fallback. A signed naked CLI was terminated without its required app
profile context; only the subsequently valid signed bundle runs qualify native
storage. These are qualification-host limitations, not ordinary-app crashes.
The final tracked probe was rerun successfully after replacing assertions with
controlled failures and adding strict UUID namespace validation.

Sequential process restoration is actual Keychain evidence, not a physical
reboot/power-loss test or an injected failure inside Apple's storage engine.
Locked-device behavior, physical iOS/Watch storage and real SDK/API/TV behavior
remain untested. No claim of hardware-key erasure or remote revocation follows
from deleting a synthetic generic-password item.

## Source qualification and remaining integration

Ten deterministic journal tests cover reconstruction, storage read/write errors,
ambiguous committed writes, malformed/oversized state, wrong-key isolation,
server-delay retention, exhausted-window preservation and twenty concurrent
reservations with one persisted winner. These use injected storage and remain
separate from the actual signed-bundle proof. Logs and immutable readbacks are
under build/qualification/vibecast-protected-repair-journal.

The shipping scanner does not call the journal yet. Future callers must hold the
complete per-key operation queue, validate explicit user intent and original
key/action/context/deadlines, persist before SDK/network work and reconcile
uncertain operations under the original receipt/challenge policy. The120s retry
budget/exact request/nonce is not yet journaled here. Replacement/two-handle
limits and key expiry/rollover need their own lifecycle transitions. Extensions
must not independently share this writer/key; no background retry, automatic key
generation or Profile-driven reset is added. Reinstallation cannot establish a
server-side per-device quota.

The unchanged-source local run passed901 Swift Testing tests in10 suites plus35
XCTest cases (936 total). Native macOS and iOS including Watch dependency
unsigned40376 builds passed. Exact-head independent review and protected
delivery remain separate checks. This source/qualification step performs no
App Attest request, public activation, HA/service change or ordinary app update.
