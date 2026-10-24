# Device-free visual follow-up

This source increment has two explicit consumer/presentation changes:
transient VibeScape permission interruptions and current shared DJ Bulletin v1.
It adds no backend contract, model interpretation, local intelligence, durable
Profile state, audio permission grant, deployment or installation.

## VibeScape interruption

Original native runs visual-button-iphone-r4/r5 failed on the actual screen:
a microphone denial produced inactive/mic2/mode1 then active/mic2/mode0.
The OS completion could clear awaitingPermission before SwiftUI delivered the
inactive phase. A separate help-only run passed two fresh popover openings;
the failure after denial was not treated as a successful full flow.

Inactive now keeps only the local visual scene, pauses its wake lease and Metal
view, and cancels non-permission voice work. Real background still closes the
visit, and all prior owner/epoch/Session/expiry/disappearance guards remain.
No voice task resumes itself. Help cannot publish after inactivation; a retained
open popover gets a fresh owner-scoped read on reactivation. There is no grace
timer, delayed authority extension or cross-domain clock assumption.

The isolated reproducible host uses actual screen/AppModel code with three
bundled synthetic fixtures. It follows the real mode flag rather than retaining
a ghost screen after dismissal. Native tests explicitly deny microphone access,
require speech to stay unknown and zero POST/context/Ask DJ requests, check fresh
help, and require background/owner loss to dismiss. Fresh test-only bundle
suffixes never reset an existing application's permission database. These tests
do not cover authorized capture/STT, real leases/directives/audio, the complete
paired Root, macOS UI, VoiceOver, physical GPU/energy or an installed app.

## Current shared Bulletin

Core Source1328 protected 8abef1f1c5a75cdd75d8a5aacff6f42dd4d6353f and
Final1329 protected 6402e13d737ee4b43566e94a000760aa8548d247 publish the existing
ordinary dj_bulletin Moment as session_shared, with exact broadcast/owner/shared
channels in both delivery fields. The private qualified owner_only/[owner]
tuple remains readable for older installations; no other/mixed channel shape is
admitted. Recognition alone grants no display, speech, artwork or action right.

The new actual-ha-wire fixture is copied verbatim, SHA256
410d3336c1b21581cc49fd6391e3098079e5ef1694c4af05219596460b2ce4ea.
Its protected Core README is 8f682ee9716ab84dcf90fcb13c8a26c91f922616246b4fd5539f49c586414972;
original source qualification document is aeda4a53aabcc5b58670d8fd2cad881ff8cf5c6833753f1aa0693a495b6ffea0.
Actual isolated HA transport/provenance is Core-owned; declared synthetic
RSS/model/music transports and NOT_RUN installed/native/audible fields remain.
No real publication or Apple execution is inferred from importing this fixture.

Consumer cases bind original current/Flow display admission and deadlines,
preserve both source links, distinguish shared display from absent owner
speech/settings/media rights, reject mixed delivery or missing authority, and
verify that serialization cannot renew expiry. Historical storage remains
publication metadata only; no news body is promoted into retained history.
No new player, widget, Watch surface, endpoint or production activation is added.

## Validation

Source and native results are recorded only after completed parent commands.
The earlier failing permission runs and original help-only PASS remain separate;
new native probes are not a real paired or audible/public-receiver acceptance.

The focused serial suite completed 48 functions in four suites (0.738s), and
all 1,286 functions in 29 suites completed serially (135.486s), both parent0
with every captured input unchanged. Full-suite source/test bytes are the final
production and package-test bytes; a subsequent diagnostic-only correction
moves the isolated UI host termination after its deferred screenshot. That
first native follow-up failed in screenshot cleanup despite two fresh help
reads (5 then6); it is retained as FAILED, not a passing qualification. The
repeat native iPhone/iPad parent results belong to the separate documentary
Finalization, not to a claim of installed or physical acceptance here.
