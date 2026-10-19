# Prepared registration: actual Keychain qualification

Compile the actual production sources and this probe on macOS:

```sh
swiftc -swift-version 6 -parse-as-library \
  Sources/DJConnectCore/RendezvousRetryWindow.swift \
  Sources/DJConnectCore/RendezvousRepairWindow.swift \
  Sources/DJConnectCore/RendezvousRepairJournal.swift \
  Sources/DJConnectCore/RendezvousRegistrationJournal.swift \
  Tools/qualification/vibecast-registration-journal/Probe.swift \
  -o /tmp/djc-registration-journal-probe
```

Use a signed **scratch app bundle** with the existing valid development
identity/profile/application-identifier, as described by the neighboring repair
journal probe. Do not create profiles, weaken storage, register/install the
bundle or replace the ordinary app. Invoke its executable directly.

Choose one fresh service `dev.djconnect.qualification.registration.<UUID>` and
run six separate processes: `SERVICE prepare`, `metadata`, `restore`, `expire`,
`verify-purge`, `cleanup`. Compare the two printed synthetic-body SHA256 values:
they must be identical. The maximum32KiB attestation is deliberately synthetic
bytes, not an Apple fixture. The probe performs no SDK/network operation.

It proves actual Keychain persistence of the original request/retry accounting,
identical bytes after a process restart and persisted removal of nonce/proof at
deadline equality. Metadata must be device-only/non-syncing. The final command
deletes only the exact synthetic service/account and checks absence. The probe
rejects production addresses and malformed UUID namespaces before accessing the
Keychain. If interrupted, clean up only this recorded synthetic service with
the same signed probe; never use a broad Keychain delete.

This is not power-loss/reboot or locked-device qualification, physical iOS/Watch
proof, attestation validation, API registration, active-key adoption or TV E2E.
Unsigned CI uses deterministic injected storage; no default Keychain data is
read or changed by those tests. Real host proof is a separate controlled action.

## Pre-SDK accounting and handoff

With a **new** synthetic service and a new signed scratch bundle, run eight
separate processes: `sdk-begin`, `metadata`, `sdk-restore`, `sdk-proof`,
`sdk-prepared-restore`, `sdk-expire`, `sdk-verify-purge`, `cleanup`.
Use the same service for every command. The first command saves a reservation
without calling Apple. The restored process refuses another SDK call, then
records a synthetic `serverUnavailable` callback. The next process reserves
after the original2s delay, checks SHA256 of the original nonce, supplies the
maximum synthetic proof and saves a registration reservation. Another process
restores that handoff and checks identical request bytes on registration retry.
Compare the two printed body hashes; they must match. The expiry commands
verify both budgets survive removal of nonce/proof. All times are controlled
inputs; this is not a real SDK callback, reboot or elapsed120s test. Unsafe
production/malformed service arguments must fail before any Keychain access.
