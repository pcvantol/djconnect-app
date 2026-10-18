# MacBook local pairing followed by remote transport

Owner reports successful pairing through the internal URL, briefly green local
connection, then external HTTPS. Fresh readback from the actual MacBook confirms
ordinary installed build40292. Only the selected configured URL/mode preferences
were read; no bearer, conversation store or unrelated preferences were inspected.
The saved internal URL is unchanged and the saved legacy connection mode is local.

Read-only probes from that MacBook to its configured private LAN origin:

- GET `/api/djconnect/v1/transport/context`, without authentication: HTTP405,
  elapsed0.068s. This proves reachability, not authenticated local readiness.
- POST to the same endpoint, JSON `{"contract_version":1}`, without
  authentication: HTTP426, elapsed0.013s, exact response
  `{"success":false,"error":"transport_security_required"}`.

The installed endpoint therefore refuses local transport before bearer
authentication. Core source `hybrid_transport.request_error` requires valid
operator direct-local ingress qualification for plaintext HTTP before processing
authentication. Missing/expired qualification, peer/interface/internal-origin
mismatch and other ingress predicates cannot be distinguished by this response.
No particular qualification-file defect is claimed.

Apple `DJConnectHybridTransport.selectRoute` withdraws the rejected local origin
and may qualify the configured external TLS origin. The presentation resolver
uses hybrid remoteReady over successful ordinary local HTTP status. Thus a
successful pairing/status read and an external Session transport can coexist;
the internal URL was not forgotten. Existing app logs show external use, but do
not record the original local transport rejection. The current probe establishes
the current rejection, not the precise first-failure timestamp.

Status: OPEN, backend ingress repair and installed authenticated local-context,
read and action acceptance required. No local-policy bypass, fabricated operator
qualification, forced green status, pairing reset, backend mutation/restart or
new build/install was performed. Consumer source needs no change to explain this
rejection; updating the MacBook alone is not claimed to repair it.

Attempted delivery of this finding to the existing Core thread was rejected by
automatic approval review because explicit authorization to message that thread
was not present in the available user messages. No message was delivered and no
indirect workaround was attempted. Await owner authorization before sending the
bounded diagnosis and requesting the owning Core writer to investigate/repair.

Owner subsequently explicitly authorized this exact handoff and local-admission
investigation/repair. The bounded diagnosis was successfully delivered to the
existing Core thread `01a120e2-b557-76c3-8568-129dbce2f2d2`. This proves delivery
only; repair and installed local acceptance remain OPEN pending Core readback.
