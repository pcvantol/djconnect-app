# Native surface push: Apple boundary and remaining integration

Source base `3e0dc12a4e564497fdcd0a86a0fd16ab2a998fe8`. This separate branch preserves Help PR213 and reviewed candidate `4f8879dd8cd2aa1367f6e16f342d1bf0bd4916e0` without changing that branch. This increment inventories and tests existing native types; it does not create a second Apple writer, enrollment, permission, registration adapter or provider effect.

## Delivered producer and current client

Core original-clock v3 is delivered source/runtime, not merely a design: Source1321 protected98f91ed0/Final1322f0c4a1aa with original qualification and the actual HA-dev264 readback. The full normative clock contract SHA is `c78cae89f3da760d08367709b01bdea1e0b01158dd2d81e6e03d6c01595742e8`; current Core reports context source `b65af6f4b4cc0023853e4b179ca59001a6b418377f92a10124097983dac1de42`, HTTP `eba31a89972a9e39d2fc2e8cd976c862e87a6841688d2b967eae7339e18334be`. Runtime delivery does not qualify the Apple clock mapping or native rights.

Apple Source202 already strictly decodes v3 context11/register9or8 as DATA_ONLY. Existing callable context/continuation is historical v2 and is not wired to an AppModel registration owner. Native pending token capture is implemented. It is not consent, enrollment, first-purpose history, read custody or server registration. No v2 fallback or UTC/arrival/rho substitute may be added to activate it.

The new API Core-only capability candidate f2df2d290aab582f0535f4f47b07f74ad2522411 and contract `3c5ddc01cfcd0469e0223c27f6dcb451d6b63fffb1d31676076a5f6092e0ed59` are local review inputs, NOT a protected qualified adoption pin. Its publication is awaiting the API task's own approval after an automatic review rejection. Apple must not publish it by another route. Core alone redeems the fixed HTTPS capability; Apple receives no API admin secret or enrollment ticket.

## Actual WidgetKit interface and callback scope

[Apple's WidgetKit push documentation](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications) describes a budgeted, opportunistic timeline reload from `aps.content-changed=true`; it does not deliver arbitrary application data to the timeline provider. The push handler's callback is for token/configuration changes, including the initial token. It is not an acknowledgement callback per received push.

Installed native SDK declarations, compiled with deployment target26:

- `WidgetPushInfo` exposes only `token: Data`.
- `pushTokenDidChange(_:widgets:)` receives that info and `[WidgetInfo]`; no payload, request nonce, read credential or original-clock sample.
- `WidgetCenter.currentPushInfo` is async optional info. `currentConfigurations()` returns current widget descriptions.
- `WidgetInfo` exposes kind/family/configuration; its Identifiable ID is WidgetInfo itself. There is no exposed durable per-placement UUID. Do not use its hashValue or manufacture a native instance ID.
- [TimelineProviderContext](https://developer.apple.com/documentation/widgetkit/timelineprovidercontext) exposes isPreview/family/displaySize/environmentVariants; no push cause or incoming message. Snapshot/gallery rendering can occur independently of a push.

The shipping handler stores only the pending native token in `group.dev.djconnect`; it does no paired registration. `getTimeline` currently reads existing local cache and emits expiry entries. A remote reload alone cannot manufacture new playback data or authorization.

App and widget are separate processes. [App groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) allow shared containers/preferences and IPC. [Shared Keychain access](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) can explicitly select an app group, but storage does not preserve a lost RAM clock/purpose witness. No Keychain protection class, delegation namespace, provisioning change or credential transfer is selected by this inventory.

## Target and token inventory

| Surface | Parent bundle | Extension / native target | Current custody |
| --- | --- | --- | --- |
| iPhone/iPad widget | dev.djconnect.ios | dev.djconnect.ios.track-insight-widget / DJConnectSessionWidget | AppGroup pending token; WidgetKit26 handler/currentPushInfo |
| Mac widget | dev.djconnect.mac | dev.djconnect.mac.track-insight-widget / DJConnectSessionWidget | Same distinct widget token path |
| iPhone/iPad Activity update/end | dev.djconnect.ios | Actual ActivityKit activity.id plus attributes.presentationID | Device-private pending token, current presentation check and per-instance token/state streams |
| Activity remote start | none admitted | no push-to-start acquisition | CLOSED |
| Native Mac Activity registration | none implemented | current ActivityKit code is iOS-only | CLOSED; no inference from iPhone continuity |

Source entitlements use development APNs (iOS aps-environment; macOS com.apple.developer.aps-environment). The API source derives topics from parent bundle plus `.push-type.widgets` or `.push-type.liveactivity`; actual provisioning/provider target acceptance is still required. Unsigned SDK tests do not establish entitlement validity or token-topic delivery.

Activity token changes cannot overwrite a successor presentation; ended/dismissed streams withdraw only their own instance. A persisted pending token is not a recovered registration, original purpose or read credential. No token is logged by these tests.

## Exact current Activity local codec

Attributes: `DJConnectSessionLiveActivityAttributes`, single key `presentationID`. ContentState aliases `DJConnectSessionSurfaceSnapshot`.

- Schema: `docs/contracts/SESSION_ACTIVITY_LOCAL_CONTENT_STATE_V1.schema.json`, SHA256 `c41f925cd2d8417f27038c9f5b99d07c641aaa13d9ffb22fcb494647f9d54bff`.
- Vectors: `Tests/Fixtures/session-activity-local-codec-profile-v1.json`, SHA256 `42870568daa9f39dc97675b0a2a89525f202b8d83e92362e25d5bbd0be9c156e`.

The schema inventories exact encoder fields and optional null decoding; it is NOT an operative strict network decoder. Current synthesized decoders tolerate unknown keys. Date uses Foundation's default seconds since2001; nil optional properties are omitted and decode-null becomes nil. The tests round-trip neutral/theme/rich examples through real source types and native ActivityContent.

Rich content includes device-local receivedUptime and receivedAt. Changing to a foreign uptime makes existing freshness checks fail even when wall expiry matches. A server cannot fill these from its own clock. This local cache codec must not be installed as an API remote profile.

[Apple ActivityKit push documentation](https://developer.apple.com/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications) requires content-state to match native default decoding; APS timestamp is Unix seconds. Update and end are distinct. stale-date marks outdated content, not guaranteed pixel erasure; offline devices may miss updates. Dismissal is not an immediate privacy-wipe guarantee.

## Required AppModel / original-registration owner implementation

No placeholder factory is installed to make this look operational. The remaining code must be implemented against the accepted owning contracts:

1. Bind native candidate inventory to the original paired installation/Profile/settings binding/active Session, native token and exact OS target. Keep Widget and Activity owners independent. Token presence and OS placement alone supply no external-content or locked-display permission.
2. Establish original first-purpose association inside its accepted original process/clock domain; capture C0 before any await. Preserve original minima across contexts/UUIDs/token rotations. Unknown/lost earlier history closes; restart does not recreate it.
3. Replace the historical v2 callable continuation with independently versioned strict v3 context/register transport and exact operation echo. DATA_ONLY values never become authority by themselves. Use a qualified conservative OS clock/rate/suspend/domain mapping, never rho=1 from a flag or fixture.
4. Own the registration task and RAM-only read credential. Synchronously invalidate local rendering/read authority and fence late completions before cancellation, remote revoke or other awaits. Never replay uncertain writes/new IDs; status may only reconcile the original operation under its original authority. Rotation keeps generation/original expiry with exact expected revision+1.
5. Owner/session/consent loss and native removal/terminal state scrub local authority. Remote revoke has separately current original rights; an ACK cannot reauthorize the owner. Lost-key/purpose reconciliation is not automatic enrollment.

## Cold Widget route A versus proposed route B

The accepted v3 A route is only original extension-owned context/registration within the SAME extension process lifetime. No app-to-extension original-pin handoff and no cold getTimeline recovery from AppGroup/Keychain/cache/UTC. A does not qualify the normal cold widget-push product.

Core/API are preparing B as a separate read-only render-delegation design, not a permission already supplied here. Required decisions: authenticated original server/owner/Session/source/target binding, original expiry and revocation, bounded online request, storage/accessibility policy, OS snapshot/cache/locked-display consent, replay and process restart behavior. B may not resume purpose/signer/enrollment or renew authority on a read. WidgetKit provides no wake payload channel for handing B to a callback.

## Activity remote profile decisions needed before code adoption

Keep the legacy local codec intact. Agree a separate native Attributes/ContentState version or explicit discriminator with migration, using safe integer UnixMS display fields without imported receivedUptime/C0/arrival anchors. Core owns original export projection/send expiry; API owns the exact APNs parser/profile and payload; Apple owns native type/default decoding/renderer.

The joint profile must separately define: app-start admission; existing Activity update/end target; remote-start=false; exact locked_display/external_content/os_snapshot_cache consent; allowed playback/contribution/artwork fields and retention; byte limit including APS; original observe/expiry sequence; stale/ended/dismissed and offline behavior; late/reordered/after-revoke events; UTC offsets±240 and clock changes; migration of old instances. OS-mediated display rights cannot be inferred from widget-only registration or a best-effort end packet. Missing rights/profile remain CLOSED.

## Actual bounded validation

External run root `/Volumes/Shared Data/tmp/pcvantol/apple-surface-push-native-20261026/` retains native SDK interface hashes, generated disposable projects and original logs/results.

- iPhone simulator: actual Xcode test3 PASS,0 failures,parent0 (`ios-r1.xcresult`).
- macOS: actual Xcode unit tests2 PASS,0 failures,parent0 (`mac-r1.xcresult`); no GUI acceptance claimed.
- Compiles real WidgetKit API references and actual iOS ActivityAttributes/ContentState/ActivityContent. Checks default epoch/null/omission, foreign uptime rejection, and distinct stale/ended/dismissed states.
- Does NOT request a token, invoke the callback, create/update/end an Activity, call HA/API/APNs, read installed caches/credentials or establish a native push receipt. Signature compilation is not notification delivery.

Product source is unchanged by this bounded inventory increment. Native owner wiring, v3 clock bridge, B read delegation and remote Activity profile are still required; this does not close end-to-end push.


## Separate remote native prototype (not shipping)

Following Core's private architecture69876208, `Tools/qualification/surface-push/RemoteActivityV1Prototype.swift` now proposes a separate `DJConnectRemoteSessionActivityAttributesV1` and explicit integer-UnixMS ContentState. Existing local type/cache/token instances stay unchanged. The new type is ONLY in the disposable test target, absent from shipping project/package targets, WidgetBundle, registration and API profiles. It cannot request an Activity or grant consent. No canonical cross-repo contract was changed.

`docs/contracts/REMOTE_SESSION_ACTIVITY_V1_PROPOSAL.schema.json` closes nine fields and the five playback fields; explicit nullable theme/playback must be present. Exact Attributes contain local random presentation ID and generation, never raw Profile/Session IDs. Data covers track/artist/album/playback-state/source-label only; artwork, URLs, Moments and commands are excluded. The companion proposal records no admitted profiles and explicitly UNACCEPTED display/export/cache/retention rights. Byte limits are UTF8, control text rejects rather than truncates, expiry relation is at most120000ms; whole APNs JSON has its own4096-byte check.

Tests model native default-codec roundtrip, exact field/type/null/unknown/overflow/foreign-clock rejection, target-generation mismatch, stale/ended/expiry and default-closed display decisions. The display-decision probe is NOT a SwiftUI/OS pixel receipt. It includes explicit counterexamples: a clock240s behind still renders data at true server+241s, and a stateless renderer cannot know an earlier sequence arrived after a later one. Those remain OPEN design dependencies, not passing privacy or ordering proofs. The native Decoder also cannot recover raw duplicate-key history; API's independent strict JSON/emission remains necessary. No AppModel interception is assumed for OS updates.

The separate remote-prototype successor passes actual native8iOS/7macOS test functions,parent0 (`ios-r2.xcresult`, `mac-r2.xcresult`). `native-r2-source-receipt.json` SHA47f31e1a0c530403ad18485db861d75aab3c20b6d8e43cfec36a4ae76272da5b binds test inputs and original logs. The r1 SDK/local-codec tests remain immutable at3iOS/2macOS; they are not relabelled as remote-prototype runs. New schema SHA0e8c404205dd5e18679d3747563df8a7c3359be440ca10e15b15c0ac04cfad2d and companion proposal SHA2a7b32d19fd7ec51c86f8d8b94eddf7c314e5e823c2e17a4358beffc7e44b121 are private review targets, not accepted runtime pins.
