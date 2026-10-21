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
Symbolic Session Mood provides an artistic palette hint only.

The source-controlled Metal shader is compiled into the native UI framework's
`default.metallib`. Runtime server/model text, external shaders and URL content
cannot become GPU code. A full-screen triangle ray-marches a continuous field of
twisted liquid ribbons and an organic spine, with analytic studio reflections.
Composition, palette and material interpolate during a visible visit. There is
no movie, image playback or frame-by-frame CPU mesh generation.

The MTKView renderer is mounted only while the root immersive overlay exists.
Flow and Forecast remain mounted underneath, retaining their own viewport state.
The overlay hides their accessibility tree and covers ordinary UI chrome; the
macOS window toolbar hides while active. The only persistent controls are the
three mode choices and a Dynamics popover. Escape exits. Changing primary
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

No visual state is Codable or sent to defaults, keychain, disk, analytics, normal
Ask DJ, Flow, history, Profile, Music DNA or playback actions. Entering also
cancels ordinary voice capture and suspends wake-word listening; general text,
recording and upload entry points refuse while the visual view is active. A
stale wake recognizer cannot log or route its callback into this visit.

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

- Seven native Swift tests cover field-preserving patches, stale apply/ACK, undo,
  scope, reset, revoke/reentry, invalid numeric input, budget/expiry, twenty
  synthetic scene identities and blocked general Ask DJ/recording/defaults writes.
- Real macOS and generic iOS preview builds compile the native Metal shader.
- Offscreen Metal on the Mac mini's Apple M6 rendered 20 synthetic contexts and
  240 frames at 960×640. Refined-shader run: median GPU 0.920ms, p95 1.421ms.
  These are GPU command timings, **not** whole-app frame-rate or sustained
  battery/thermal measurements. Original images and the report are retained in
  private qualification output, not in user state or this source tree.
- Five locales include the initial controls and honest unavailable messages.

Native iPhone/iPad/Mac fullscreen UI/VoiceOver/resize acceptance, prolonged
thermal/battery qualification, twenty *actual playback occurrences*, continuous
voice follow-ups and independent visual/security acceptance are **NOT_RUN**.
The native UI automation service timed out; offscreen images cannot substitute
for those checks. SwiftPM command-line builds copy the shader resource but do
not produce a metallib; that presentation path fails gracefully. Xcode app
targets compile and bundle the actual metallib, without runtime compilation.
