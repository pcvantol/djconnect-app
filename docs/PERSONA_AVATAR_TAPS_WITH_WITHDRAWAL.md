# Avatar taps with current reaction withdrawal

Owner reports the designed single/double/triple avatar comments still do not work. Root cause in current Apple source: PersonaReactionConsumerGate.isQualified was hardcoded false, so the existing exclusive gesture/context-menu/keyboard/VoiceOver control was never mounted. Its historical producer-gap document applied to an older Core version. Read-only Core main83744790decc6ef8940795dc2c9c0e3fb058173b now exposes a paired-owner reaction observer and original UUIDv7 cancellation fence. No Core source, installation or live request changed.

## Source implementation

Remove the permanent local gate. Runtime capability admission additionally requires the exact delivered withdrawal_contract v1 (paired_owner_actions, observe command, withdrawn event, required display/playback observation, one observer, bounded server guard cadence, stop on connection loss, no deadline renewal) and durable_original_uuidv7_fence_until_operation_deadline cancellation semantics. Old producer discovery remains unavailable for taps, while base persona support is preserved.

Existing exclusive native taps remain one/check_in, two/playful and three/easter_egg. Use current confirmed Session/settings/persona/mood/voice/output/owner and existing busy/lifecycle guards. Server-curated text stays ephemeral and never becomes a local authored joke, Ask DJ turn, Moment or history entry. Existing selection haptic occurs on admitted request; accepted-response feedback occurs only after observer admission. Speaker-only output remains explicitly text-only/unqualified instead of substituted client audio.

A dedicated paired-owner socket is bound to the qualified transport/install/device and original operation ID/epoch/Session. Send the exact flat existing observe fields; do not poll the receipt as source authority or replay the operation. Validate initial observation's version/request ID/reaction/Session/private-no-store/original expiry before showing text or starting speech. Hold one bounded observation with monotonic terminal withdrawal: a withdrawal racing the initial result cannot re-admit content. Dedicated socket accepts only its withdrawal event; malformed frames or socket failure stop/withdraw. Existing paired action authentication now accepts the exact baseline command subset plus only the known delivered settings/observer additions, failing closed on unknown commands. No settings subscription is sent.

Controller closes bubble/stops owned renderer on observer withdrawal, socket/route lifecycle loss, local conflict/context change or original expiry; close its observer when the run is cancelled/completed. The original maximum30seconds is unchanged. Model's audio admission also checks the live observation before/after async byte preparation and while rendering; disconnect cannot authorize already downloaded audio. The existing tombstone-producing cancellation operation is reused. No fallback transport observation, background activation, automatic comment or extra server/model/provider call is introduced.

## Validation boundary

Source diff and register checks only. Added unrun regressions for legacy capability rejection, supported synthetic metadata, original observation identity/deadline, no re-admission after withdrawal and controller text/output cancellation. Immutable historical fixtures remain unchanged. Native multi-tap arbitration, audio, websocket handshake/event ordering/capacity, cancellation races and regressions must be compiled/executed during the next explicitly requested build. No build/test execution, native preview, installation or actual server reaction request here. Last installed40447 unchanged. Source-only PR179, no merge; this is not installed/physical gesture acceptance.


## Native input correction — 24 October

A mechanically extracted view diagnostic reproduced a remaining input defect on
an owned iPhone simulator: the nested SwiftUI exclusive gestures delivered a
double tap as `check_in`; single and triple taps selected their correct kinds.
Changing the nesting order did not fix the failure. Both original failed runs
are retained externally, not relabeled as successful qualification.

The presentation component now uses native UIKit tap recognizers with explicit
failure dependencies for one/two/three taps, and corresponding AppKit click
recognizer failure delegation. Recognition dispatches only the final kind.
Coordinator callbacks use the current closure and ignore detached views.
The hand indicator, context menu, keyboard and accessibility alternatives remain.
The existing AppModel capability, owner, Session, settings, observation, busy and
speech/output checks are unchanged and still run before a request.

The input-only component can be hosted without AppModel or real credentials via
`Tools/qualification/persona-reaction`. This does not grant authority or author
DJ text locally. Original private candidate tests passed three cases on each
owned iPhone/iPad simulator; unsigned macOS framework compilation passed. Those
candidate tests used synthetic counters and did not execute a server reaction,
audio, VoiceOver or real Mac input. Exact integrated-source validation and
independent review must still be recorded before delivery. Runtime context-menu
warnings and animation-quiescence delays remain preserved in the native logs.


The focused controller run also exposed a late-result path: an expired completed
response could return before admission while leaving the original run pending
until its initial 30-second bound. It now closes that same run immediately,
retaining the original operation cancellation fence and requiring a fresh human
tap for another attempt. No automatic retry or replacement identity is added.
The controller's internal clock seam defaults to the same device `Date()` calls;
it only lets tests advance past an immutable source expiry without a fragile
250-ms scheduling window. It is unrelated to surface-push clock qualification
and supplies no backend lifetime or authority. The original failed test run is
retained alongside the deterministic expiry and late-operation-callback tests.


Integrated validation: the exact final view/host/UI-test bytes passed three
native UI tests on each owned iPhone/iPad simulator, including six successive
tap choices, menu selection and synthetic busy/withdrawal guards (parents zero,
all 300 frozen input hashes stable). The later controller correction passed all
21 focused persona tests in 0.450 seconds, including immutable expiry and the
late original-operation cancellation (parent zero, all 300 hashes stable).
The controller was not invoked by the view-only native hosts; these are separate
component scopes, not a full paired/native reaction or audible-acceptance claim.
The whole-source candidate CI and independent review remain required.
