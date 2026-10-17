# Apple direct HTTP/WS adoption preparation

Status: SOURCE IMPLEMENTED AGAINST MERGED CORE, NOT INSTALLED. Existing sole Apple writer retained.
Installed Mac mini and iPad remain40113; no transport app installation here.

Core sourcePR1184 is still open at candidate
6a0c3398f34f2281095b4ab7357aad55ffb2be23. Hassfest failed because of the
missing network manifest dependency; the separate correction is Core-owned.
The final protected source/artifact and installed readback are not delivered.
The candidate contract is docs/product/HYBRID_LOCAL_TRANSPORT_POLICY_V1.md.

## Implemented preparation

DJConnectHybridLocalPolicy is an internal pure validator, deliberately unused
by the route coordinator and socket. The existing TLS gate is unchanged.
It accepts a local response only at the exact preconfigured paired local
origin, with all policy1 fields, qualified_direct_http mode and request-specific
requires_authenticated_tls=false. The global capability is never admission.
External HTTP, forged private-host prefixes, foreign ports/origins, credentials,
queries and fragments fail. Legacy TLS contexts still work. IPv4/IPv6 local
classification alone grants no permission to release credentials.

Candidate context/capability fixtures are copied without alteration from the
published candidate, explicitly marked OPEN_PR_NOT_MERGED_NOT_INSTALLED.
Tests cover complete/missing policy, candidate contexts, external downgrade,
origin binding and existing no-replay/demultiplexing/lifecycle behaviour.
These are source tests, not installed Core or physical transport acceptance.

## Runtime integration after final producer delivery

1. Verify final protected source, artifact, installed HA-dev binding and exact
   current contract fixtures. Reconcile any change from the candidate parser.
2. Qualify only an already paired local URL before credential-bearing context
   requests; retain installation-ID checks. Never discover authority from an
   unauthenticated capability or user-supplied server advertisement.
3. Apply request-specific policy to context and WS auth_ok. Map admitted HTTP
   to WS and HTTPS to WSS; do not weaken external route validation.
4. Treat HTTP426 and WS auth_invalid/transport_security_required as route
   withdrawal. Close/invalidate that route, preserve pairing/Profile/cache and
   recover through previously trusted TLS only. Pending mutations reconcile
   the original operationID/epoch; never execute again after possible send.
   Current prepare() maps all auth failures to notSent; preserve the security
   withdrawal distinctly so it cannot dispatch fallback to the withdrawn route.
5. Keep composer draft, selection and scroll anchored through foreground and
   network recovery; qualify real owner reads/actions and background resume.

## Actual topology boundary

Fresh Docker readback: desktop-linux context, homeassistant container bridged
on homeassistant_ha_net,172.18.0.2/16,gateway172.18.0.1;8123 published0.0.0.0.
Core observed LAN traffic as192.168.65.1, not the real iPad address; internal URL
unset. Published port reachability is not direct-ingress qualification.
Do not allowlist the Docker NAT gateway or fabricate source_preserved evidence.
A real source-preserving ingress and explicit operator qualification record
are still needed before native internal WS acceptance. No Docker/network,
certificate, pairing or Core configuration was changed by this preparation.

Cleanup: one active writer worktree, no newly eligible merged stale branches;
active/untracked project directories and evidence preserved.

## Route-withdrawal implementation followup

The source coordinator/socket now preserves routeWithdrawn separately from
pairing authority and generic notSent. auth_invalid/transport_security_required
at handshake or during a pending reply fails as route withdrawal. HTTP426 with
that exact code uses the same path. Withdrawn origins are temporarily excluded
from route selection; the paired token, Profile and UI state are not cleared.
Before possible send no fallback execute is dispatched. After possible send,
only original operationID/epoch status is queried through the remaining trusted
TLS route. Active reads can recover on that trusted route without mutations.
The existing TLS-only gate and installed40113 apps are still unchanged.

Fresh CorePR1184 now has published candidate
 a0714b44d22918cbefa5ed0dfe3fc21afff5160a after its manifest correction.
It remains OPEN, so this is not a final producer/artifact or installed pin.
Candidate fixture6a0c339 remains a preparation fixture; replace/reconcile it
against the final delivered pin before activating HTTP/WS.

Focused verification:20 local-policy/Hybrid tests PASS, including four explicit
route-withdrawal cases (before-send, after-send, HTTP426, active read recovery).
Log:/private/tmp/djc-route-withdrawal-final4-tests.log.
No real LAN/WS network transition or physical installed transport acceptance is
claimed by these injected-wire tests. No new install or Core mutation performed.


## Merged producer adoption update

Core sourcePR1184 merged as0f92b74e76ae055efdbf2b375d95c58e86328e27.
The earlier candidate/open/TLS-only preparation sections above are historical.
The exact merged contexts/capability replace the candidate fixture in
Tests/Fixtures/hybrid_local_core_0f92b74.json.

The source route coordinator now admits only the already configured local HTTP
candidate, validates the complete request-specific policy and installationID,
and passes qualified-local permission to the paired-action socket. The socket
maps HTTP to WS, HTTPS to WSS and independently validates auth_ok policy. A
conflicting security mode withdraws the route before executing. Remote HTTP
remains forbidden. IPv6 local candidates use the same qualified policy gate.
App-model transport construction now includes paired localHTTP-only setups;
About/diagnostics report actual HTTP/WS versus HTTPS/WSS and no active origin
while offline. The global requires_authenticated_tls capability is unchanged.

24 focused tests PASS, including HTTP/WS demultiplexed reads, unqualified local
context -> trustedTLS fallback, mismatched socket policy -> no execute,
route-only withdrawal/original-ID reconciliation and protocol display names.
Log:/private/tmp/djc-local-ws-adoption-final3-tests.log.
Signed native Mac and iOS/embeddedWatch build40114 PASS:
/private/tmp/djc-local-ws-40114-mac-build.log,
/private/tmp/djc-local-ws-40114-ipad-build.log.
Built from the qualified selective snapshot with only exact transport/diagnostic
patches; unrelated incomplete widget/Speech source excluded. Build40114 not yet
installed. Actual ordinary apps remain40113.

Fresh installedHA-dev still records62c8156d, internal_url=null, no ingress
qualificationfile; actual LANcontext HTTP426. No fake qualification, gateway
allowlist, pairing reset or parallel Core deployment. Final Core artifact/
installation and real source-preserving ingress remain joint acceptance gates.
The existing Core writer received this readback and exact consumer progress
under the user's explicit HTTP/WS handoff authorization. No new Core scope.
