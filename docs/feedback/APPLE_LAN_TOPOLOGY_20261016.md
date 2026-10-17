# HA-dev LAN transport investigation — 16 October 2026

## Verified boundary

Apple build40116 is installed on Mac, iPad and iPhone. The selective qualified
source includes the Core policy1 consumer; the full writer is not an installable
candidate because unfinished widget/Speech work is present. Core finalmain
58205056c235a73488591591dd3d83f80f7bf847 is independently matched against all166
HA-dev integration files, with no mismatches or extra files. These observations
are software/install evidence, not native LAN acceptance.

The existing LAN endpoint is reachable, but its authenticated transport context
remains426 and the operator qualification record is absent. Docker Desktop
currently masks LAN peers as192.168.65.1. The gateway cannot substitute for the
real iPad address. No ingress record, allowlist or source-preserved assertion has
been fabricated.

The bounded25-second host-network probe and its two connection-refused results
are recorded in APPLE_CORE_INSTALLED_TRANSPORT_20261016.json. That probe does
not establish whether enabling Desktop host networking would preserve source
addresses. Current read-only inventory finds only Docker among the installed
VM applications; standard Parallels/UTM/Colima/Lima executable paths were absent.
Docker Engine reports29.8.2. The Desktop CLI enable command exposes model-runner,
not a documented host-network toggle. No global network setting was changed.

## Supported next experiment

Docker documents Desktop host networking as opt-in with Settings / Resources /
Network / Enable host networking / Apply and restart. Its implementation is
layer4 and has no direct access to host interfaces. The documentation does not
qualify this exact machine's real LAN peer preservation. Consequently, enabling
it is a candidate experiment, not a proposed qualification record.

References checked during this investigation:
- https://docs.docker.com/engine/network/drivers/host/
- https://docs.docker.com/desktop/features/networking/
- https://docs.docker.com/engine/network/drivers/macvlan/

Before any global restart, coordinate with the existing Core writer and other
active container leases. Apple has requested the next natural idle window under
the user's existing HTTP/WS handoff authorization. Core subsequently confirmed its own Speech/hassfest lab containers have ended,
but homeassistant, music-assistant-server, Wyoming and an existing Apple presence
container remain active without a coordinated restart window. Core explicitly
did not release those shared resources. Do not interrupt active leases or assume
a response authorizes a new Core source scope.

At a coordinated window: capture current settings and container health, use the
supported Desktop setting, then repeat an isolated no-mount/read-only bounded
listener test from Mac and the real Pi. Inspect raw socket peer and actual
container interfaces. If the real peer/interface requirements are not met,
restore the setting; do not compensate using forwarded headers or a gateway
exception. A Linux host or a genuinely bridged Linux VM is a separate topology
candidate requiring a migration/rollback plan, not an implicit HA relocation.

Only after genuine ingress evidence and Core-owned operator qualification may
native iPad localWS acceptance run. Check authenticated installation identity,
About actual LAN protocol, LAN/external/LAN transitions, background recovery,
original-operation status, draft/selection/scroll preservation separately.
External HTTPS readiness and a successful TCP connection do not close these gates.

## Preservation

No global Docker restart, HA deployment, certificate, proxy, firewall, pairing,
Pi service or virtual-machine installation was performed. The iPhone remains
passcode-locked, so physical iPhone UI qualification remains open. Worktree
readback shows one active Apple writer; only main and the current branch are
merged. No stale ref is eligible for removal. Untracked project directories and
all source/evidence remain preserved. Current internal free space is about10GiB.

## Completed official Desktop host-network experiment — 02:06 local

This supersedes the earlier untested-hostnetwork/no-global-restart status above.
After fresh Core no-active-lab/deploy readback, the existing user-authorized
LAN/Docker experiment used the official Resources / Network / Enable host
networking / Apply and restart flow on Desktop4.95.0. Settings backup and all five
original container IDs/images/policies/networks were recorded beforehand.

A30-second no-mount/read-only/cap-dropALL/64MiB ephemeral listener on18089 then
received actual Mac loopback and actual Pi10 LAN requests. Both raw socket peers
were127.0.0.1. Visible interfaces remained VM192.168.65.3 and internal bridges;
no physical192.168.1.x interface. This is direct evidence that this Desktop host
mode also masks the LAN source. It cannot meet the current direct-ingress
contract; its loopback peer is not proof of local origin. No operator record or
policy exception was created.

Host networking was turned off again through the official UI and restarted.
All five original containers are running with identical ID/image/restart policy/
network; own presence lab with restart=no was explicitly restored after each
restart. The ephemeral probe is absent. HA-dev frontend returns HTTP200.
Persisted HostNetworkingEnabled=false replaces the previous absent/default-false
key; no other settings key changed. Core received exact outcome and resource
restoration. See APPLE_DOCKER_HOST_NETWORK_PROBE_20261016.json.

No HA code/config/Profile/pairing, proxy/certificate, firewall, Pi service or
producer qualification change. Native LAN/WS remains OPEN. A genuinely direct
Linux network topology needs a separate concrete migration/rollback plan;
repeating the Desktop host-mode experiment is not the next step.
