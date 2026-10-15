# Internal HTTP/WS transport requirement

Human explicitly requires internal HTTP/WS and external HTTPS/WSS. The previous
HA-dev certificate/proxy plan is superseded. No certificate/proxy was installed.

Actual Mac mini LAN address:192.168.1.134. Existing Docker compose publishes
8123:8123 on all interfaces; application firewall is already disabled. Mac and
physical Pi10 receive HTTP200 from http://192.168.1.134:8123/. No NAT, Docker or
firewall mutation was necessary. No WAN/router forwarding was added.

Credential-free POST to /api/djconnect/v1/transport/context returns HTTP426
transport_security_required. Current Core hybrid_transport.request_error and
requires_authenticated_tls=true contract block local HTTP, and Apple currently
rejects plaintext origins and hardcodes wss for paired actions. This requires
producer contract/server and consumer changes together, not a certificate bypass
or ignoring the producer TLS requirement.

Human explicitly authorized handing this requirement to existing Core task
01a120e2-b557-76c3-8568-129dbce2f2d2. Core ACK: finish separate reviewed PR1179
Finalization first, then canonical SYNC_PROMPTS/architecture/contract before the
bounded LAN HTTP/WS producer implementation under the same writer. Paired auth,
install-ID binding, operation-ID/reconciliation and external TLS retained.
Apple must consume the exact producer pin/fixture before installing the change.

Physical iPad preflight limitations: standalone test runner URLSession returned
Local network prohibited; this is runner permission, not proof of failed LAN.
Actual Safari screenshot shows HA404 at the LAN address, confirming HTTP
reachability but not WebSocket success. New www static registration was absent;
no HA restart was done merely to register a test page. These failed/bounded probes
are retained under /private/tmp/djc-ipad-{lan-preflight,safari-lan-ws}*.xcresult.
No authenticated app localWS, action, fallback or network-transition PASS yet.

Independent requested presentation change: local Apple commit efac177 changes
connection-details-link foregroundStyle to white, including the info icon.
Not yet installed on physical devices. Current iPad app remains40099.
