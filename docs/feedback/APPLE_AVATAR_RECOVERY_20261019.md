# Avatar observations and automatic backend recovery — 2026-10-19

Ordinary build 40356 reproduced audible replay with a resting avatar on the
MacBook, followed by a music-backend-unavailable state that cleared only after
manual refresh. The earlier speech and Session border correction remains main
PR140; this is a separate continuation.

The avatar's observation scope incorrectly required playback-backend availability.
That is independent of authorized microphone capture and admitted local speech.
Remove that one condition while retaining foreground, authenticated Profile,
connection, active Session, settings binding, epoch and delivery-scope checks.
Actual recorder/player/delegate evidence still decides listening/speaking.

All transitions to backend unavailable now schedule bounded recovery, including
metadata-only failures. Foreground activation and the existing 10-second Session
poll rearm recovery if needed. The recovery loop's own 2-to-10-second backoff
replaces the unrelated eight-second full-refresh throttle. Recovery remains
foreground-only and stops on restored availability, background, offline, runtime incompatibility or pairing
withdrawal. Session discovery remains independent of music availability.

Existing opt-in debug logs add boolean-only capture/output observation diagnostics;
normal diagnostic export also exposes foreground/connection/scope booleans. No
Profile identifiers, content, audio or new backend wire fields are added.

Regression checks cover missing music backend without invented activity, retained
connection/owner requirements, automatic metadata recovery without a manual click,
and existing read-only Session polling/background cancellation. Installed physical
avatar motion and MacBook recovery acceptance remain pending qualification.
