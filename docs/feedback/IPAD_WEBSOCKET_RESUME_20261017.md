# Physical iPad WebSocket resumption — 2026-10-17

Owner requested completion of the outstanding physical iPad WebSocket tests.
This is a fresh readback, not acceptance of the outstanding flow matrix in
`IPAD_WEBSOCKET_E2E_20261015.md`.

## Executed

- Existing native PhysicalProbe ran successfully against the ordinary installed
  `dev.djconnect.ios` on iPad `00008027-000211140231002E`.
- Exported and visually inspected the physical screenshot. Apple's local-network
  permission dialog is still open, over the ordinary app's crash-report sheet.
  No permission button was pressed by automation. Owner was asked to tap Allow.
- Read only the app's persisted route settings. Base, local and remote URL slots
  all still contain `https://victory-curvy-refold.ngrok-free.dev`; the old mode
  preference is `local`. This preference is not evidence of an actual local route.
  Temporary raw preferences were deleted immediately after URL extraction.
- Fresh authenticated HA-dev `/api/config` and HA management WebSocket readback
  confirm `RUNNING`, internal URL `http://192.168.1.134:8123`, and unchanged external
  HTTPS origin. Management WebSocket connection and read commands passed via LAN.
  This uses HA authentication and does not prove paired DJConnect action WS.
- Local paired transport-context preflight returned HTTP426 with
  `transport_security_required`. The operator qualification file
  `djconnect_direct_local_ingress.json` is absent. No qualification was invented,
  no source-address check bypassed, and no Docker/network/security setting changed.

## Outstanding

Physical screen/command/Broadcast/lease/recovery and network-transition cases
remain NOT RUN. They cannot be reported as PASS while the system permission
blocks the ordinary app and the server refuses the local paired transport.
HA's changed internal URL does not itself rewrite the app's persisted URL slots.
Once permission is granted, inspect ordinary app connection details and configure
the verified local candidate through the supported UI; preserve external URL,
pairing, Profile and Session. Native local paired action testing additionally
requires genuine source-preserving ingress qualification or a supported trusted
TLS ingress. No re-pairing or production deployment is part of this attempt.

## Evidence

- `/private/tmp/djc-ipad-ws-20261017-read.xcresult`
- `/private/tmp/djc-ipad-ws-20261017-read.log` — native test succeeded
- `/private/tmp/djc-ipad-ws-20261017-read-attachments/3BD37D0A-FB7E-4553-A5B6-1D0F7AF9EC13.png`
- `/private/tmp/djc-ipad-ws-20261017-read-attachments/636FE86B-86E2-4531-903C-840568722658.txt`
- `/private/tmp/djc-ipad-ws-20261017-routes.json` — URL fields only
- `/private/tmp/djc-ipad-ws-20261017-preflight.json` — sanitized HA readback

Source publication pause remains in effect; no app code, pairing or Session was
changed. Unrelated untracked Xcode project directories were preserved.
