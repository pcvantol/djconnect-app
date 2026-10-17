# Wi-Fi still selects external HA

Owner screenshot shows authenticated external/ngrok HTTPS route while iPhone is
on home Wi-Fi. The active-origin display intentionally follows qualified Hybrid
transport, not the Wi-Fi icon or a configured URL.

Fresh read-only preflight on2026-10-17:
- HA-dev hostLAN192.168.1.134, Docker8123 published0.0.0.0.
- POST http://192.168.1.134:8123/api/djconnect/v1/transport/context without tokens,
  read-only context payload, returns426/transport_security_required before auth.
- djconnect_direct_local_ingress.json is actually absent from HA config root.

This is reachable-but-refused local ingress, not evidence of an Apple cosmetic
mode error. Existing Core policy requires genuine source-preserving/excluded-
proxy operator evidence for direct plaintext, or authenticated trusted TLS.
Do not manufacture a qualification file or rename the remote connection local.
The existing Core writer received the current user finding and requested
operational fix under the already authorized task-messaging relationship.
No second Core writer, network mutation, provider switch or re-pairing performed.
Physical localWS acceptance remains pending producer/deployment correction.

User is away from iPad and cannot confirm the UI-automation setting now. That
physical test remains open; do not continue repeated automation initialization
attempts until the device-side requirement can be confirmed.

## Apple40222 and producer deployment readback

The installed and candidate manifest both report4.0.0-rc.1, but the installed
session_speech.py hash differs from the current Core-writer candidate. New TTS
changes are not yet installed. The ingress policy modules match, so merely
copying the candidate cannot be assumed to remove the LAN426 gate. The existing
Core writer received this distinction and the owner request for HA-dev delivery.

Apple's generated app configuration used the invalid
NSAllowsArbitraryLoadsInLocalNetworking key. Replaced with
NSAllowsLocalNetworking and explicit private/loopback IPv4/IPv6 CIDR HTTP
exceptions. No global arbitrary-load setting or public TLS downgrade.
Official references:
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking
- https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSAppTransportSecurity/NSExceptionDomains

Validation:715 regressions PASS (provider40221-full-qualified.log); additional
ATS key/scope regression PASS (djc-lan40222-tests.log). Signed iOS and macOS40222
builds PASS; actual product plists verified for build number, correct key and
seven private/loopback CIDRs. Installed build40222 freshly read back on iPhone
00008150-001409183C07801C, iPad00008027-000211140231002E and local Mac mini.
Previous Mac40221 retained. No runtime LAN/WebSocket PASS claimed; producer
ingress correction and real route test remain pending. No iPad automation
retry while owner away.

## Verse iPad/HA-dev-reconciliatie — 17 oktober, na40274

Verse17oktread: gewoneiPad40272 bewaart internhttp://192.168.1.134:8123 en externvictory-curvy-refold.ngrok-free.dev. Zelfde installatie als draaiendeHA-dev; huidigeconfiguration.yaml bevat hetzelfde interneadres. HA-dev177/177integratieblobhashes gelijk aan Coremain0adaef7d5acd9cbe84b97d2f684c6f2e705dc27c. Credentialvrije lokale transport/context geeft426/transport_security_required; direct-local-ingressqualificationbestand ontbreekt. InterneURLsync is in deze observatie correct; veilige lokale ingress/pairedWS blijft open, geen herstel door cosmetische moduswijziging of nieuwepairing.

Bestaande Core-/operatorlane moet een werkelijk gekwalificeerde LAN-ingang leveren (vertrouwde lokaleTLS of bewezen direct-local-ingress volgens huidige policy), gevolgd door echteiPad-/WiFi-/resume-/WS/fallbackacceptatie. Geen fabricage van qualificationrecord, lease/TLSdowngrade of client-tokenreset. Native route blijft extern zolang lokaal niet toegelaten wordt.

De geïnstalleerde iPadpref en gewone applog zijn alleen-lezen opgehaald. De app
meldt Local Wi-Fi/LANavailable; dat is geen toelating van de beschermde transport-
route. Installatievergelijking gebruikt uitsluitend de niet-geheime installbinding
en toont alleen matchcount; geen devicebearer of nieuwekoppelcode geëxporteerd.
De oude .storage/core.config bevat andere/legeURLvelden; de huidige expliciete
configuration.yaml en iPadroute zijn gelijk. Geen backendconfig gewijzigd.

Privé:route40275-ipad-preferences.plist/runtime.log, container-readback.txt,
local-preflight.json en ha-dev-exact-main-readback.json.40275 is een readlabel,
geen nieuwe nativebuild/installatieclaim.

[Verse Core-overdracht](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6235227035), exact teruggelezen.

[Apple-lanereadback](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6235236730), exact teruggelezen.
