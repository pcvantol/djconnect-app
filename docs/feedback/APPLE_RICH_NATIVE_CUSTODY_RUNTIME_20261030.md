# Rich Session native custody and runtime guards

This increment connects necessary guards to the existing foreground cache,
AppGroup, renderer and ActivityKit calls. It retains the single rich widget
and single rich Live Activity. It does not enable a successor permission,
registration or provider factory from DATA.

## Concrete runtime changes

- `PassiveSessionSurfaceModel` captures actual native clock samples before
  scheduling each authorization/read task. The original capture stays in RAM
  with its exact foreground grant/frame; an OS cache cannot reconstruct it.
- Artwork completion stages pixels into the original cache object. It does not
  reset receivedAt/receivedUptime. Identical observations, including as_of-only
  reads, retain those original anchors. A same-sequence changed frame is rejected.
- Every read must still match the original grant, owner, Session and settings
  generation/revision. Scope changes withdraw local work before waiting. Parent
  cancellation reaches child tasks. Late images/errors cannot repopulate or
  clear a replacement generation.
- The actual AppGroup cache invocation checks current wall/uptime both before
  encoding and after encoding/size validation immediately before storage.
  Snapshot storage independently checks current fields after preparation.
  Deterministic clock seams are internal to tests, not public admission APIs.
- `SessionSurfaceNativeCustody` is held by the real AppModel. Its private tickets
  bind current installation/binding/Session/settings, presentation and frame
  generations. Foreground changes fence queued starts without declaring that
  a retained native Activity lost its identity. Checks run after queued-task
  awaits and immediately before SDK invocation. They are necessary guards,
  not original rich-start permission.
- Actual ActivityKit request results can create a private `NativeTarget` holding
  the native Activity object/ID and pre-request original attributes bytes.
  Retired handles do not revive; ambiguous inventory is not first-match adopted.
  Cold inventory cannot construct this process-local captured target.
- The rich renderer independently checks each field's source interval and its
  original receive/uptime cap at paint. Aggregate validity cannot keep an expired
  contribution alive or let wall rollback renew a playback field.
- Widget and Live Activity backgrounds use a 0.75-second opacity/very small scale
  transition only when track identity or the confirmed palette changes. No timer,
  repeat loop or extra reload is introduced. Reduce Motion, reduced luminance
  and stale states disable it. Actual OS animation/display acceptance is separate.

## Typed receiving inputs and remaining qualification

`DJConnectNativeSurfaceClockCapture` is private-init and non-Codable. It samples
ContinuousClock, mach_continuous_time/timebase, optional actual kernel boot UUID,
process identity, uptime and wall time. These are real observations; timebase is
not an independently qualified cross-domain rate. Original permission, rate and
restart restoration remain explicitly missing. Neither capture equality nor a
ticket Boolean supplies those qualifications.

Local profile `darwin-mach-continuous-warm-v1` brackets the Swift sample with
actual counter reads. Its local counter measurement requires the same actual
current PID/private process lifetime, kernel boot and timebase, rejects rollback,
and floors full-width integer/rational conversion with overflow rejection. The
result is a Mach-domain measurement, not a server/native rate guarantee. Native
runtime probes demonstrate implementation behavior only. No caller-supplied
rho, default ratio or cold-restoration factory is introduced.

The future independently authenticated Core response must match the locally
retained original pre-await attempt, permission/purpose, pair/settings/source
revisions and frame/slot/subject/media revision. Both original purpose remaining
and individual field remaining intervals are needed. Response/as_of is not C0.
Initial display permission must precede the first SDK effect; a later ActivityID
or enrollment cannot repair its absence. Existing foreground capture is not a
widget-v3, Activity-background or cold-process delegation.

Core's jointly selected private R3 artwork constraints are separate from the
legacy PNG cache: preserve original PNG/JPEG bytes in a successor association,
256,000 bytes per asset, two slots and 1,000,000 serialized cache bytes. Verify
authenticated digest/length/MIME, actual ImageIO type, one complete image,
dimensions up to 4096 per axis and 16 million pixels, with exact frame/slot/
subject/asset/revision/rights/deadline/attribution/alt-text bindings. Decode only
for aspect-fit paint; no stored recoding/thumbnail, crop, WebP or provider/read
fallback. Unsupported artwork clears only its slot, retaining independent text.
This increment does not reinterpret the old cache or claim that a new
authenticated artwork wire is implemented.

Actual service/installation/signer authority, exact authenticated successor
wires, qualified clock mapping, background roles, enrollment, provider delivery
and physical push acceptance remain separate Core/API/Apple integration work.
The first planned transport is content-free invalidation plus direct Core read;
widget invalidation is not host-app wake or Live Activity refresh.

## Validation scope

The isolated validation directory is
`/Volumes/Shared Data/tmp/pcvantol/apple-rich-native-custody-20261030`.
`full-r4` passed all 1,402 Swift tests in 36 suites. The iOS Simulator build,
including the widget and embedded Watch dependency, passed in `ios-build-r5`.
The preceding `ios-build-r4` failed on sandbox access to Xcode caches and
CoreSimulator, before source compilation; it is retained as a setup failure.

The exact same four regression tests were also run against the actual
predecessor model at `3bec8aae7f5139cc07c6e2ac444c2f3cc695aaac`.
`red-four-r3` failed all four with nine assertion issues; the corresponding
current-source tests pass. `paired-four-tests-r3.json` binds the shared test
block and predecessor test file. Earlier fixture/compiler failures remain
separate and are not counted as causal regression evidence.

These results qualify the tested local behavior and compilation only. They do
not establish OS transition rendering, original source permission, simulator
APNs delivery, physical-device delivery, production activation or a cross-clock
rate bound. No device installation or provider operation is performed by these
checks.
