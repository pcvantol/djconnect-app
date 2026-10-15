# Apple Hybrid transport adoption — current candidate

Workpackage: DJC-APPLE-HYBRID-TRANSPORT-ADOPTION-V1-20261013.
Sole source writer: build/apple-40017-recovery/source, codex/apple-dj-presence-v1.
User explicitly requested implementation and lifted the installation/testpush
pause. Source publication/CI/merge remains outside the current authorization.

## Producer pin

Final Core: f0a7ff4bb878247db9ab25c4a22320f17d806cd6.
Source-equivalent producer: d552a5524245c82aae83b350eddf14126d3c117b.
Final handoff: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6188493265
Finalization: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6189021515
The pinned synthetic fixture is Tests/Fixtures/hybrid_transport_v1_core_f0a7ff4.json.
Core installation evidence does not constitute native Apple acceptance.

## Implemented source

- Shared foreground context/route coordinator; HTTPS and authenticated installation
  equality; coalesced probes and bounded remote/offline backoff.
- Paired action WSS with one reader, ID/connection demultiplexing, bounded writes,
  cancellation fences, heartbeat, authentication deadline and lease renewal.
- UUIDv7 original operation identity, epoch, same-ID status reconciliation after
  possible send; confirmed-without-body remains confirmed without regeneration.
- Existing request/CAS/subject envelopes retained; no generic mutation replay.
  HTTP-only voice/uploads/history paging and unsupported commands remain HTTP.
- Separate Broadcast with cursor recovery, validated snapshots/events and an
  honest missing-coverage notice. Background/authority cleanup remains bounded.
- Automatic transport replaces the normal opt-in toggle and HA-token issuer path.
- About reports combined health, actual Hybrid route/transport and authenticated
  origin. Non-green connection popovers offer Details → About on all platforms.

## Evidence boundaries

Final candidate:572 Swift tests passed, including twelve new Hybrid protocol/
operation tests and route-origin clearing on background. Five languages validate
1134 keys. Native Mac/iOS builds and Apple Development signing passed. Build40064
is installed on Mac mini and physical iPad. These software tests use injected
wires, not real TLS or physical network transitions. Installed observations and
limitations are recorded in APPLE_FEEDBACK_STATUS_20261015.md.

Still OPEN: physical Mac/iPhone/iPad LAN/external and
background/resume transitions, foreign-network rejection, energy behaviour,
independent review, protected publication and final native acceptance. Legacy
HTTP request families still use the existing transport manager; the shared
Hybrid coordinator owns the adopted action and active-session paths.

Live push has a separate unresolved post-bootstrap401 boundary. Both Macs need
an authoritative pairing diagnosis; no token restoration or speculative re-pair
is part of this candidate. iPad retains pairing; iPhone was last unreachable.
