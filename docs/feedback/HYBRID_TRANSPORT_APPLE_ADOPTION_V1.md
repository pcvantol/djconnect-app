# Apple Hybrid transport adoption — pickup and gap matrix

## Scope and current gate

Workpackage:DJC-APPLE-HYBRID-TRANSPORT-ADOPTION-V1-20261013.
Keep existing sole Apple writer in build/apple-40017-recovery/source, branch
codex/apple-dj-presence-v1. Preparation follows the current40061 bug checkpoint;
no Swift contract adoption or silent expansion of an approved candidate yet.

Fresh lane readback:
- Selection: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6149955349
- Early producer: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6185756317
- New detailed handoff: https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6186713492

The latest comment still names03bcabf2bfb05a9a9159295098cd7acc84e84ff1
as a local checkpoint with further dirty hardening work, explicitly NOT the
final qualified producer pin. Final published schema/main/artifact/fixture
checksums and exact consumer admission remain outstanding. The17-case fixture
is historical; recent Core reports of54 HA/TLS cases do not qualify native
Apple behavior or authorize using mutable code as the contract.

## Current source observations

| Area | Current Apple source | Required bounded change after final pin |
| --- | --- | --- |
| Route selection | DJConnectAppModel.withHomeAssistantClient builds a transport manager per call;15-second remote preference is already present | Reuse route ownership, add one shared coordinator/probe with final trust, hysteresis and lifecycle states; preserve the existing fixes |
| Action socket | DJConnectTransportConfiguration/FastPathPolicy require opt-in plus legacy HA WebSocket auth | Adopt paired_owner_actions at /api/djconnect/v1/actions/paired; do not enable the legacy HA-wide socket as a shortcut |
| Settings | SettingsView canShowWebSocketFastPathToggle and the persisted model flag remain | Remove normal-use toggle and migrate obsolete overrides once automatic transport is implemented; retain meaningful read-only diagnostics |
| Credentials | DJConnectWebSocketSessionAuthProvider still obtains client.webSocketSession() credentials | Remove dependency on /websocket/session for this path; use the existing paired identity with authenticated install binding, never a broad HA token |
| Response matching | DJConnectWebSocketFastPath.sendResult sends then calls receive per request; IDs are allocated but this method does not verify reply-ID/connection-ID | One receive task, pending registration before send, bounded writer, per-connection demux, cancellation and replacement-epoch fences |
| Retry semantics | HATransportManager uses allowsOperationReplay; existing call sites already disable it for some effects | Central original operation identity and acceptance-aware status reconciliation, replacing generic mutation fallback without regressing existing cancellation/auth/provider/CAS handling |
| Broadcast | Separate paired subscribe/recover socket and ordinary HTTP snapshot recovery already exist | Keep action/Broadcast responsibilities separate; consume final opaque recovery cursor/watermark contract, show honest snapshot coverage gaps |
| Session/UI lifetime | Shared foreground active-session discovery, context epochs, pending seeks and pinned Moment subject already exist | Preserve these across route transitions and rejected late responses; no duplicate Session, playback transfer, regenerated body or lost draft/search/scroll |

## Contract-bound implementation order

1. Pin producer main, artifact and complete fixtures, compare schemas/compatibility
   and freeze the initial Apple candidate separately from the current bugs.
2. Typed transport context, UUIDv7 operation identity, epoch, deadline and receipts.
   No personal result bodies persisted in a client journal; follow final contract.
3. One shared endpoint/installation-trust and route coordinator. Prove TLS hostname
   or existing explicit pin before releasing a paired secret, then authenticated
   install-ID equality. Foreign Wi-Fi, HTTP200 and standalone challenges are not
   trust. No redirects with secrets, invented external URL or TLS bypass.
4. Paired action actor with one reader/demux and bounded queue/writer. Preliminary
   limits8 outstanding/64 queued responses/64KiB/256 IDs/two overlapping action
   sockets are NOT constants to ship until confirmed against the final pin.
5. Same original UUIDv7/epoch/payload/deadline across WS/HTTP. Pre-send failure
   differs from sent_unknown; reconcile status after possible send. Confirmed
   with result_available:false remains confirmed, never a new model/provider
   invocation to reconstruct a body. New deliberate user action gets a new ID.
6. Heartbeat, quiet socket, auth deadline, lease renewal and bounded recovery.
   Network/lease/protocol errors preserve pairing; qualified owner/Profile/source
   withdrawal clears only the affected authority/private data. No perpetual
   background polling or request-per-LAN-timeout storm.
7. Integrate existing command/Ask DJ/Track Insight/playback/Mood/Presence routes,
   retaining client_message_id, CAS, source guards and HTTP-only voice/uploads/
   files/history paging. Then remove the setting/issuer dependency and migrate
   overrides with five-language diagnostics/help.

## Required acceptance, all pending for the new protocol

| Layer | Evidence required | Current state |
| --- | --- | --- |
| Core baseline | Exact published producer + real fixtures, counters/limits | Await final pin; early reports are not Apple PASS |
| Swift concurrency | Out-of-order concurrent replies, duplicate IDs, bounded capacity, oversize, late replaced-socket reply and cancellation | OPEN |
| Effect safety | Next/toggle/queue/Play/Ask DJ/Insight disconnect before send, after accept, after effect/before reply; original-ID receipt; exact effect/generation counts | OPEN |
| Trust | Correct/wrong install, cert/hostname/redirect; no secret to unproven route; expiry and auth/Profile/source withdrawal | OPEN |
| Recovery | Half-open/no pong, quiet/paused/music-only, lease expiry, conflict/epoch expiry/server restart, missing result body, snapshot gaps | OPEN |
| UI continuity | Same Session-ID, Moments, conversation IDs, selected A remains A, pinned Insight, draft/search/scroll, Mood/Presence races and end/successor | OPEN |
| Real devices | Mac/iPhone/iPad LAN→external→LAN; mobile data, foreign Wi-Fi, offline/recovery, background/resume, missing remote config and ineligible local TLS | NOT_RUN |
| Measurements | Switch/recovery latency, request/probe/effect counts, backoff, bounded resources/energy | NOT_RUN |
| Delivery | Independent reviews, required checks, protected merge, exact-main readback and Finalization; separately authorized installs | NOT_STARTED |

Current40061 legacy regression baseline:552 tests PASS29.595s; unsigned Mac/iOS
builds PASS for accumulated fixes. This does not qualify the new protocol.
The physical iPad standalone UI runner fails enabling automation mode; resolve
that environment issue before native acceptance, never substitute a Mac test
or synthetic renderer test for the requested iPad→Pi test.

No new Swift change, deployment, install, push/CI or merge in this pickup.
