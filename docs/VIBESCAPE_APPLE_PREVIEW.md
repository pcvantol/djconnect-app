# VibeScape Apple preview — not production acceptance

Owning work: [Apple177](https://github.com/pcvantol/djconnect-app/issues/177),
[Core1271](https://github.com/pcvantol/djconnect/issues/1271).

This is an initial native renderer and presentation increment. The third active
Session choice is available only with `DJCONNECT_VIBESCAPE_PREVIEW`. Ordinary
shipping builds preserve Flow and Forecast. No live Visual Director endpoint,
capability or wire DTO is assumed or added. Do not enable production from this
preview or describe the complete feature as delivered.

## Local implementation

`VibeScapeScene` is a closed, renderer-local value model. The GPU consumes four
composition coordinates, a bounded RGB palette and finite motion, depth,
roughness and deformation values in 0…1. Native seed diversity is volatile;
there is no recorded seed, invented genre, audio analysis or BPM synchronization.
Symbolic Session Mood selects all three existing Session palette colors
(including lime/blue/green Energy). The shader uses these for its liquid forms,
reflections and flowing light ribbons. Core supplies the mood name, not a live Visual Director
palette response; this is local artistic coloring, not audio analysis.

The source-controlled Metal shader is compiled into the native UI framework's
`default.metallib`. Runtime server/model text, external shaders and URL content
cannot become GPU code. A full-screen triangle ray-marches a continuous field with analytic colored
studio reflections. The field combines smooth liquid lobes, drifting bubbles and cropped foreground
pools over layered luminous waves. It follows the owner's supplied liquid/light
reference, replacing the earlier isolated interwoven knot. Composition, palette
and material interpolate during a visible visit. There is
no movie, image playback or frame-by-frame CPU mesh generation.

The MTKView renderer is mounted only while the root immersive overlay exists.
Flow/Forecast search has no collapsed inline button or reserved search row.
iPhone exposes search in the existing More toolbar popover; iPad and macOS
show a direct toolbar button. Both the button and Command-F open the current
mode's inline field without switching Forecast to Flow. The shared bound scroll
position aligns that field to the top content boundary below the native toolbar;
field geometry and keyboard completion settle the same target after insertion.
Forecast registers its nested children as scroll targets. There is no competing
one-shot proxy scroll, and user tracking/dragging immediately releases alignment.
Forecast's local search remains available independently of history search.
Flow and Forecast remain mounted underneath, retaining their own viewport state.
The overlay hides their accessibility tree and covers ordinary UI chrome; the
macOS window toolbar hides while active. In Flow and Forecast the three-way mode
picker belongs to the scrolling content above the playback header, with no
pinned overlay. The picker precedes the current-track header in scroll content;
the initial scroll anchor is the header, so the picker starts above the viewport
and pulling the artwork down reveals it. It scrolls into and out of view.
On iOS the picker reserves the measured toolbar-control height below itself
(44-point minimum). The initial current-header anchor is set before first layout;
the artwork then starts eight points below the native content boundary instead
of the previous combined 32-point top padding. This leaves the native toolbar
between picker and artwork, without a device-specific status-bar offset.
The selected pill uses a dark Session mood tint. VibeScape remembers the
visible picker's global frame at entry and aligns its own picker there, using
the same width and padding. This geometry is presentation-only RAM, not user
data or an authorization input. A vertical glass Dynamics slider sits
at the right edge, with automatic-follow reset underneath. Both controls fade away
after three seconds; tapping their invisible control regions toggles them.
Taps elsewhere nudge the liquid and its waves locally, without showing controls.
Swipes outside those control regions also nudge along the finger's path, sampled
at most 30 times per second with at least eight points between samples. A swipe
starting in a control region never deforms the canvas or reveals controls;
crossing one skips its area. Releasing the finger adds the final local impulse.
At most four screen-space impulses remain in RAM for2.6seconds. Each produces a
soft dent with a 160ms onset and non-oscillating decay, instead of alternating
bright/dark ripple rings. Smooth saturation bounds overlapping impulses to
avoid abrupt normal/lighting changes while fingers rest or move slightly.
They preserve the scene's style/composition, consume no interpreted
turn budget, and invalidate old renderer/request tickets. Track changes and
visit exit discard them. Reduce Motion uses an immediate static deformation
and expiration instead of an animated decay. Dragging the
slider suspends hiding and starts a fresh three seconds on release. Reduce
Motion disables the control animation; an accessibility action reveals them.
Dynamics shows its percentage and uses a separate 180ms response instead of
the scene's 1.8s morph. Auto is prepared to consume a qualified whole-track
intensity, but current Core main df757b13 explicitly supplies no qualified
numeric basis: credit-only and unmeasured metadata paths return nil metrics.
Legacy/deterministic/demo scalars are not trustworthy recording measurements.
The production adapter therefore keeps numeric qualification closed and returns
nil even for finite matching legacy values; no analysis/model request is made
by opening VibeScape. A qualified numeric source/subject contract is required
before enabling this adapter. No new wire basis is invented here.

The prepared resolver also requires a present playing/paused item, matching
nonempty title/artist, matching album/duration when both supplied (1.5-second
duration tolerance), and a finite 0...1 value; credit-only and unavailable
analysis are excluded. These matches alone never establish qualification.
Missing/invalid/unqualified values use neutral 50%, not a mood/energy estimate.
Positive resolver tests explicitly inject synthetic numeric qualification;
they are not producer interoperability evidence. This is not live beat sync.

Dragging switches to Manual until reset or visit exit, retaining the override
across track changes. Auto continues to remember incoming values while manual;
reset resumes the latest server value or neutral fallback. The thumb animates
for 350ms on automatic changes (disabled by Reduce Motion); native GPU Dynamics
still uses its separate 180ms response. Automatic updates do not consume an
interpreted-turn budget or affect style masks. Revocation clears both sources.

The Dynamics midpoint preserves the baseline clock multiplier;
the calm/intense ends change rotation speed and deformation over a much wider
range. Reduce Motion keeps a static frame but still shows the different shape.
Escape exits. Changing primary
navigation, backgrounding, owner/epoch/session changes or ending the Session
revokes the visit. GPU delegate disposal pauses drawing. Reduce Motion produces
an on-demand static frame; low power/serious thermal state uses 30fps and fewer
march steps. Drawable pixel scale and three in-flight submissions are bounded.

`VisualDirectorVisit` owns RAM-only scene/undo state: up to eight undo checkpoints,
32 interpreted changes, a 30-minute monotonic visit lifetime and exact
visit/occurrence/revision tickets. A patch preserves all absent fields. Continuous
visit constraints can cross a *qualified* occurrence change; current-track
patches and undo expire. A render acknowledgment is accepted only after a
successful GPU completion for the converged current revision. No parsed result
alone can earn an applied-success toast.

`VibeScapeFrameFence` distinguishes a submitted frame from a successful GPU
completion. Only one converged frame per revision awaits acknowledgment.
Revision changes immediately discard that reservation; a late or duplicate
callback cannot acknowledge or clear a replacement frame. Failed completion
does not mark the revision applied. A failed current acknowledgment frame stops
the native view and shows the existing unavailable notice, including in static
Reduce Motion mode. Three local tests cover failure/retry identity, replacement,
duplicate completion, exit/reentry and visit expiry. This is a renderer fence,
not a live source-lease check or completed success-toast integration.

No visual state is Codable or sent to defaults, keychain, disk, analytics, normal
Ask DJ, Flow, history, Profile, Music DNA or playback actions. Entering also
cancels ordinary voice capture and suspends wake-word listening; general text,
recording and upload entry points refuse while the visual view is active. A
stale wake recognizer cannot log or route its callback into this visit.

## Native explicit-style actions (no wire adoption)

The local coordinator separately tracks explicit current-track fields and
continuous-visit fields. A current-track correction overlays the held visit
style without modifying it. A later visit-scoped change removes only its own
fields from the current-track mask. Hold promotes only the remaining explicit
current-track mask; it never freezes untouched generated palette/material or
motion. A track handover discards that track mask and undo, retains the visit
mask and creates a fresh composition in the same original visit.

Variant changes composition only, preserving style fields and Dynamics. Undo
restores both masks, the original autonomous baseline and slider state; resetting
to DJ clears both masks and returns the slider to its midpoint. Repeating an
already-established patch, an empty hold/reset or an unchanged slider value is
no-effect: it produces no new revision or application acknowledgment. An equal
value may establish a previously absent explicit scope constraint once.

These are local renderer operations, not an implementation of the draft Core
wire union. Original occurrence/visit/turn admission is still required, and the
preview cannot authorize them without a qualified occurrence. No live voice
route or GPU-earned toast integration is claimed by these changes.

## Local interpretation-turn fence (still no transport)

`VisualDirectorTurnFence` is a client-local helper, not a Core DTO, endpoint or
new authority grant. It accepts an already-qualified adapter's original source
deadline and a synchronous check of that same original authorization. Each turn
has a new local UUID, even after cancellation at an unchanged scene revision.
It admits one request at a time and at most32 attempts during one continuous
visit, counting cancellations and no-effect results. A track change does not
refund the budget. A source lease cannot extend an earlier turn; the local
maximum is30seconds and a shorter original source deadline always wins.

Visit exit/revoke, reentry, a track/revision change and expiry cancel the pending
turn and release its captured context. Completion checks the original turn,
scene, source authorization and monotonic deadline again, consumes the turn
before invoking a local application callback and refuses duplicates. It does
not emit a GPU acknowledgment or a success toast. It holds no transcript,
response body, wire token or persistent state. Production integration remains
absent until the actual Core context/contract is delivered; the preview still
has no authoritative occurrence and therefore cannot start interpreted turns.

Six additional native tests cover same-revision cancellation/replacement,
source renewal versus original expiry, clock rollback, owner/revision/exit
withdrawal, attempt budget across tracks, missing context and immediate release
of a captured context object. These cases plus the initial eight visit tests and six explicit-style
tests plus the three frame-fence tests, mood-refresh and bounded-touch tests form the current25targeted VibeScape tests. Previous full-suite/build/GPU results remain bound to their original
heads; this local follow-up does not inherit native voice or hardware acceptance.

## Explicitly unresolved producer/UI boundaries

Core confirmed that current `item_id` is a recording hash and `updated_at` is a
poll timestamp. Neither, nor a historical playback-observed entry, proves the
current playback occurrence. The preview therefore has **no authoritative
occurrence binding** and **no live voice route**. A changed item conservatively
starts a fresh scene with no retained overrides. Same-recording replay/seek
identity and source expiry await Core's actual qualified context projection.

Tapping the visual or its accessibility speech action currently gives a truthful
unavailable notice, never permission prompts, microphone capture, an Ask DJ
request or a fake applied confirmation. Native transient STT, the four-turn voice
chain, renderer-committed success toast and transport/admission remain open until
Core supplies the agreed versioned fixtures and implemented capability. Local
patch tests are not evidence of actual voice interpretation.

## Actual validation so far

- Twenty-five targeted native Swift tests cover field-preserving patches, stale apply/ACK, undo,
  scope, reset, revoke/reentry, invalid numeric input, budget/expiry, twenty
  synthetic scene identities and blocked general Ask DJ/recording/defaults writes.
- Real macOS and generic iOS preview builds compile the native Metal shader.
- Offscreen Metal on the Mac mini's Apple M6 rendered 20 synthetic contexts and
  240 frames at 960×640. Refined-shader run: median GPU 0.920ms, p95 1.421ms.
  These are GPU command timings, **not** whole-app frame-rate or sustained
  battery/thermal measurements. Original images and the report are retained in
  private qualification output, not in user state or this source tree.
- The GPU probe supports both landscape and portrait dimensions and also renders one identical composition at Dynamics0/100%, at
  the same initial clock and three seconds later. It asserts different static
  pixels and greater temporal change at100%. This verifies actual shader output,
  not physical slider touch handling or user acceptance.
- The native GPU touch regression renders the same scene at two input positions,
  checks local pixel change exceeds a distant region, and verifies expired touch
  input produces exactly the original pixels. It does not replace physical
  iPhone touch/hit-area acceptance.
- Five locales include the initial controls and honest unavailable messages.

Native iPhone/iPad/Mac fullscreen UI/VoiceOver/resize acceptance, prolonged
thermal/battery qualification, twenty *actual playback occurrences*, continuous
voice follow-ups and independent visual/security acceptance are **NOT_RUN**.
The native UI automation service timed out; offscreen images cannot substitute
for those checks. SwiftPM command-line builds copy the shader resource but do
not produce a metallib; that presentation path fails gracefully. Xcode app
targets compile and bundle the actual metallib, without runtime compilation.
