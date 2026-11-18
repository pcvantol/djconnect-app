# Watch Session flow — simulator qualification, 22 October 2026

Scope: repair the ordinary paired Watch → iPhone → HA-dev Session flow. The
owner authorized simulator builds/testing for this request. Existing unrelated
source work is preserved; no physical-device installation or release occurred.
Candidate build: 40449, source WIP based on main `8c349e7581a13c7700643df0fcf14366feb9e0ae`.

## Corrections

- Persist the generated Watch installation ID and pairing code before the first
  companion registration. AppStorage's generated defaults alone did not commit
  them, allowing a new model/start to register a different device.
- Activate WatchConnectivity for restored paired installations too. Initial
  foreground state may already be active and legitimately skip its transition
  callback; previously that left the paired cold-start route disconnected.
- Refresh after initial companion readiness/reachability, coalescing ordinary
  ready messages instead of creating a request feedback loop.
- Use the actual wall/monotonic clocks when rendering a freshly received Session.
  TimelineView's scheduled context date can predate the asynchronous receipt,
  causing the freshness fence to keep displaying Loading. Original native Moment
  deadlines and the 30-second foreground lease are unchanged.
- Recheck delayed HA setup using the existing Watch registration/token while the
  iPhone is foreground. No replay of the pairing POST or borrowed phone bearer.
  Completing the Watch setup does not pair the phone's independent identity.
- Ignore stale pairing responses for a replaced registration, and do not present
  Let's Rock again for an already paired Watch after a repeated completion.
- Add start/end controls through the existing backend routes, with owner/session
  revalidation, one write per user action, stop confirmation, and readback after
  uncertain results. An explicit Use current action only accepts a fresh read;
  it never repeats a write. Distinguish connection, pairing and read failures.
- Retry only the coherent settings/Session read once if a concurrent owner edit
  splits the independent responses. Invalid or unsuccessful snapshots remain
  closed; no local Session, commentary or publication is manufactured.

## Verification

- Required third-party preflight completed; system tool upgrades skipped.
- Ordinary Debug iOS simulator build including embedded Watch app succeeded.
  Both installed simulator bundles independently report 4.0.0 (40449).
- Full Swift run: **1,140 tests / 23 suites passed serially**. The earlier parallel
  run failed through shared fixture/timing interference; its log is retained.
- Localization: **1,432 keys passed**. Brand validation and `git diff --check` pass.
- Actual HA-dev: Watch-owned settings v3 and active Session both HTTP 200.
  The durable Watch ID matches the companion registration after cold restart;
  both apps report paired. The owner completed normal HA pairing and chose their
  existing profile; no admin token, synthesized grant or fixture server was used.
- Native watchOS XCUITest `watch-session-live-7.xcresult`: **passed** after cold
  restart, showing the real Session start time and controls.
- Extended native `watch-session-live-9.xcresult`: **passed**. Expanding Session
  Flow revealed original server contributions; opening the end confirmation and
  using watchOS's system Close button preserved the Session; shared DJ settings
  opened without changing them. The final server read confirms the original
  active Session is unchanged.

Native testing uses a separate, nonshipping XCUITest project. Earlier failed UI
attempts and their artifacts are retained alongside the final results. They
exposed both real application faults and differences between watchOS system
selectors and ordinary SwiftUI button labels.

Evidence directory (local, contains private UI artifacts):
`/Volumes/Shared Data/tmp/pcvantol/djc-watch-session-flow-20261022/`.
`final-verification.json` records source hashes, bundle readbacks, pairing and
HTTP outcomes without bearer tokens. `pre-watch.patch` preserves the earlier WIP.

## Qualification boundary

The existing user Session was deliberately preserved. No actual start/end POST
was executed against that running profile during native qualification; the end
confirmation was cancelled. Native voice playback, background push, physical
Watch installation and acceptance are not claimed by this test.

After the last readback, both owned simulator apps were stopped and the HA-dev
resource was explicitly released to the existing Core writer for their already
authorized installation. No Core source, HA configuration, credentials or
production deployment was changed by Apple.


## Whole-candidate review correction — Watch write owner fence

Core's independent PR183 review found that the iPhone proxy's start/end write
read settings followed by Session without the trailing settings fence already
used by foreground reads. An original Watch intent for ProfileA/noSession could
otherwise pass a split settingsA/noSessionB pair and write into the currentB.
The action now uses `DJConnectWatchSessionSnapshot.read`, compares the original
intent against that coherent snapshot and checks cancellation before one write.
Both proxy operations call that helper; existing non-replayed transport and
unknown-outcome accounting remain. This is a read fence, not a new atomic server
write precondition or a guarantee against a later unobserved backend switch.

A contract-valid synthetic64hex binding switch reproduces one forbidden write
with the old two-read implementation (RED, two assertions). Fixed code admits
zero writes and its stable-owner path performs exactly one write; an uncertain
reply is not retried. Four adjacent tests pass0.005s. The initial new test used
an invalid-length binding and also failed its fixture assertion; that log is
retained and is not the valid causal baseline. The corrected RED/GREEN logs are
`watch-write-owner-red-valid-binding.log` and
`watch-write-owner-green-valid-binding.log` in the night evidence directory.
No physical Watch or server effect is claimed by this regression.


## Whole-candidate P1 correction — late companion setup completion

Core's exact3eef/07c4 audit found that a successful late status read could restore
an old registration and send its captured token after clear/replacement. The
Watch receiver accepted token-bearing messages before checking their target.
No real credential or device operation was used to establish this finding.

The phone now captures a pairing generation before task scheduling and checks
original device, persisted Watch pairing intent, code, selected HA origin and
bearer around setup waits. Explicit new pairing, clear/replacement and foreground
loss withdraw the generation. The shared main-actor readback helper rechecks both
success and error and performs the commit synchronously after that final check.
An old task/defer cannot clear a successor's task or in-flight marker. The initial
pairing POST also checks its original generation before changing local state.

The result envelope carries device_id, pairing_intent_id and pair_code. Watch
persists its installation-local intent before registration and rotates it on
reset even if its device ID remains unchanged. Receiver validation precedes any
token-store write, and a different queued token cannot overwrite an existing
token within the same intent. Uncorrelated legacy messages cannot install new
credentials. Existing already-paired same-device/code upgrades retain their
existing bearer when adopting intent metadata; pending/reset/replacement setup
cannot use that path. This is an internal Apple companion protocol, not a new
backend identity, personal model, grant or server contract.

Seven focused functions pass0.012s, including nine late context/cancellation/ABA
cases, late error suppression, exact receiver/reset/legacy checks, token
continuity and persistence/restart/corruption. An extracted real-helper probe
restores the two missing guards: RED gives one stale commit and one wrong-target
token write; fixed GREEN gives zero of each. Its immutable receipt is
`watch-pairing-causal-proof/receipt.json` under the night evidence directory.
This is a bounded helper/callsite proof, not a replay of the entire historical
phone/Watch executable or physical/HA acceptance. Ordinary iOS/Watch/widget
compilation succeeds unsigned after registering the new shared source file;
the first external qualification project omitted that file and its failed log
is preserved. Whole-candidate review and the new full suite remain required.
