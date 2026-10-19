# Actual protected recovery-journal qualification

Compile actual production sources plus the synthetic probe:

```sh
swiftc -swift-version 6 -parse-as-library \
  Sources/DJConnectCore/RendezvousRetryWindow.swift \
  Sources/DJConnectCore/RendezvousRepairWindow.swift \
  Sources/DJConnectCore/RendezvousRepairJournal.swift \
  Sources/DJConnectCore/RendezvousRecoveryJournal.swift \
  Tools/qualification/vibecast-recovery-journal/Probe.swift \
  -o /tmp/djc-recovery-journal-probe
```

Use a new signed scratch app bundle with the existing valid development
identity/profile/application-identifier, following the neighboring repair-journal
probe. Do not create profiles, install/register the bundle, change the ordinary
app or weaken storage. Invoke its executable directly.

Choose a fresh `dev.djconnect.qualification.recovery.<UUID>` service and run
seven separate processes, using that same service: `begin`, `metadata`,
`restore`, `retry`, `expire`, `verify-purge`, `cleanup`. The first persists a
maximum2048-byte original clientData fixture and occupied assertion reservation.
The restored process refuses another assertion, reads back original bytes/hash,
then supplies a maximum4096-byte **synthetic** assertion and saves a prepared
request with one lost-response outcome. The retry process gets original request
bytes at the2s boundary; compare both printed request hashes. Expiry removes
nonce/clientData/request and preserves consumed accounting/handle. The exact
synthetic item is removed and absence verified by cleanup. Unsafe production or
malformed namespace arguments must fail before accessing Keychain.

This combines actual macOS device-only/non-sync Keychain persistence with a
controlled supplied clock, not a120s wall-clock soak, reboot/power-loss or locked
keychain test. The fixture is not an Apple assertion/clientData response. No SDK,
key generation, network/API/HA request, receipt verification or active-key adoption
occurs. If interrupted, clean up only this recorded synthetic service/account
with the same signed probe, never with a broad Keychain delete. Unsigned CI uses
injected storage and never touches default Keychain items.
