# VibeScape microphone — speech permission callback crash

The owner reports an immediate microphone crash across devices in VibeScape.
The ordinary installed Mac40450 crash at2026-10-23 10:58:53+0200 supplies an
exact observed cause: Speech invokes its authorization completion on
`com.apple.root.default-qos`; Swift traps in `_dispatch_assert_queue_fail` /
`_swift_task_checkIsolatedSwift` inside `VibeScapeVoiceControl.toggle`.
Microphone and Speech privacy descriptions are present in the iOS and Mac
source plists. This observed failure is callback actor isolation, not evidence
that the user denied permission.

The VibeScape authorization bridge explicitly marks the legacy SDK callback
`@Sendable`, resumes its checked continuation without touching UI state, and
returns to its MainActor caller. The same explicit boundary is applied to the
existing AppModel Speech authorization callback and to the on-device file
transcriber callback reached after recording. Transcription still extracts
immutable text/error values before scheduling its existing MainActor update.
Permission decisions, original visit/owner/deadline/cancellation guards and
on-device-only recognition remain unchanged. No backend or Profile change.

The new regression invokes the actual VibeScape bridge from MainActor with a
legacy, unannotated SDK-shaped completion executed on a global queue. It checks
all four authorization statuses and return to MainActor, plus synchronous
completion. It does not replace the SDK completion parameter with a Sendable
parameter that would hide the original inheritance bug.

A separate disposable executable uses the exact production bridge. Fixed code
returns successfully; removing only the explicit Sendable annotation traps with
SIGTRAP on the global queue, with the same dispatch/Swift actor frames as the
installed crash. Original OS reports and failed test output stay private.
Causal receipt: `/private/tmp/apple-visual-microphone-causal-20261023/receipt.json`.
Production summary: `/private/tmp/apple-visual-microphone-evidence-20261023/production-crash-summary.json`.

The initial default Swift Build test attempt failed during resource-bundle
signing due to Finder metadata in the existing build cache, before tests ran.
The native SwiftPM backend is used for the actual regression run; that first
infrastructure failure is retained separately. No new ordinary app build or
installation is performed. Physical permission/recording/transcription on each
supported device remains separate from source and callback qualification.

## Corrected validation

- Actual production-bridge regressions: 2 test functions PASS, including all
  four status values on a background SDK callback and immediate completion.
- Full serial native SwiftPM run: 1,211 Swift Testing tests /24 suites PASS
  128.374s; 86 XCTest tests, five existing explicit skips, zero failures.
- Exact extracted production bridge typechecks with the iOS26+ SDK under Swift6.
- Counterfactual without Sendable: actual OS SIGTRAP/actor-dispatch assertion;
  fixed executable exit0. No mocked permission API was called on a real device.
- Whitespace validation PASS. Existing source privacy descriptions remain present.

Original logs are under `/private/tmp/apple-visual-microphone-*-20261023.log`;
this validation does not include a new ordinary build or physical installation.
