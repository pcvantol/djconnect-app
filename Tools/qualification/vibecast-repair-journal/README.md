# Real Keychain repair-journal qualification

The probe compiles the actual production journal and window, with an isolated
synthetic Keychain service. It never uses App Attest, HTTP, HA credentials or a
production journal address. It accepts only services named
`dev.djconnect.qualification.repair.<UUID>` and fixed account `synthetic-v1`.
`cleanup` deletes only that exact synthetic service/account in the non-syncing
data-protection Keychain. No broad Keychain delete/search is performed.

```sh
swiftc -parse-as-library \
  Sources/DJConnectCore/RendezvousRepairWindow.swift \
  Sources/DJConnectCore/RendezvousRepairJournal.swift \
  Tools/qualification/vibecast-repair-journal/Probe.swift \
  -o /tmp/djc-repair-journal-probe
```

Run the executable inside a properly signed **scratch app bundle** with the
existing Apple development identity, valid provisioning profile and matching
application identifier. This is not a request to change signing settings,
create a profile or install/replace an ordinary app. An unsigned process fails
with missing entitlement(-34018); a signed naked CLI without its required
profile is not qualified. Do not weaken the store to the legacy macOS Keychain
or ordinary defaults to make these environments pass. Keep unsigned CI on the
deterministic injected-storage tests instead.

Use a fresh UUID service and invoke the scratch bundle's executable directly
as five separate processes, in this order:

1. `SERVICE write` — persist one synthetic reserved attempt.
2. `SERVICE metadata` — verify actual WhenUnlockedThisDeviceOnly and non-sync metadata.
3. `SERVICE restore` — restore the first in-flight fence; complete it and reserve the second.
4. `SERVICE exhaust` — restore the second, complete it and refuse a third attempt.
5. `SERVICE cleanup` — remove the exact synthetic item and verify absence.

The journal's internal namespace injection is compiled directly into this
qualification executable; production public callers only have the shared journal
at its fixed address. Multiple sequential processes here prove actual persisted
restoration, not concurrent-process locking, reboot/power-loss recovery, device
lock behavior or production scanner integration. No actual App Attest handle is
created: the stored handle is the literal synthetic label in this probe.
