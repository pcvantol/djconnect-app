# VibeScape: four Session-character worlds, v1

Owner authority: [Apple #177](https://github.com/pcvantol/djconnect-app/issues/177),
[approved extension](https://github.com/pcvantol/djconnect-app/issues/177#issuecomment-6576638276),
[approved references](https://github.com/pcvantol/djconnect-app/issues/177#issuecomment-6576772333),
[Core counterpart](https://github.com/pcvantol/djconnect/issues/1271#issuecomment-6576658339).
This extends the existing Apple writer and draft PR295; it does not close #177.

## Adopted private references

Private Drive metadata and authenticated downloads were verified. All four
original reference images were opened for visual comparison. Exact original
bytes, source URLs, sizes and SHA256 hashes are preserved in
[the manifest](assets/vibescape-families-v1/manifest.json). The Home image and
approved composite were extracted from the approved package and matched its
published hashes. These files are documentation; none enters an app target,
texture, bitmap effect, animation or runtime cache.

| Confirmed Session value | Reference | Procedural implementation |
| --- | --- | --- |
| `home_dj` | [Home](assets/vibescape-families-v1/home-reference.png) | Existing transparent liquid/glass lenses, joined or elongated forms, floating droplets and optional flowing light lanes. |
| `radio_dj` | [Radio](assets/vibescape-families-v1/radio-concept.png) | Curved satin-metal discs, open hoops, rods and counterweights; opposing rotations and continuously seeded sculptural arrangements. |
| `club_dj` | [Club](assets/vibescape-families-v1/club-concept.png) | Dark monoliths, offset planes, spatial frames and suspended lattices; thin emissive edges, negative space, floor reflection and controlled parallax. |
| `festival_dj` | [Festival](assets/vibescape-families-v1/festival-concept.png) | Procedural 3D point/filament blooms and organized spiral flows; coherent strands, gradual expansion/curl and bounded detail. |

The reference screenshot's old glass effect belongs to **Home**, irrespective
of the Festival choice visible in that old screenshot. Current native comparisons
use the same central Session Mood palette for every family, including identical
grey palettes. Identity comes from geometry/material/movement, not recolouring.
The references guide artistic direction; these are not pixel-identical replicas.
Final physical-screen artistic acceptance remains separate.

## Authority and source changes

The shared Screen consumes `DJConnectSessionRuntime.confirmedPersona`, its
revision floor and unconfirmed-revision state. The existing character control
and CAS/settings route remain the only mutation owner. Pending choices never
switch worlds. Equal-conflicting/stale revisions cannot roll back an accepted
world. Missing/conflicted authority produces an explicitly unavailable neutral
canvas; it never silently substitutes Home. Owner/Profile/Session withdrawal
closes the visit. New persona revisions invalidate old voice tickets and undo;
compatible explicit colour choices and manual Dynamics survive.

Only the existing authenticated Visual Director context response supplies an
opaque playback occurrence. Progress, wall-clock playback updates, track title
and item ID are not occurrence identities. A changed item immediately retires
old tickets without inventing a composition seed. Foreground idle observations
are spaced ten seconds apart; reads pause while voice is busy and stop/revoke
on leaving or losing the original source. The context route is a bounded,
non-replayed **POST read**; it does not change playback/settings. At most two
idle 15-second leases overlap the voice acquisition/revalidation budget. Missing
or failed context leaves the artistic scene in place without fabricating a new
occurrence. Same-item replay is detected through a changed server occurrence.

## One relative Dynamics control

The existing 0…1 slider has Calm — Follow DJ — Intense endpoints. All family
multipliers are exactly **1 at 0.5**. Automatic baseline motion derives from the
confirmed family and Mood, independently of numeric Track Insight. No BPM,
measured energy, live microphone analysis or personal recommendations are made.

| Family | Speed low/high | Excursion low/high | Evolution low/high | Parallax low/high | Complexity low/high |
| --- | --- | --- | --- | --- | --- |
| Home | .24 / 2.05 | .48 / 1.65 | .60 / 1.45 | .72 / 1.20 | .78 / 1.25 |
| Radio | .30 / 2.20 | .32 / 1.82 | .40 / 1.90 | .80 / 1.25 | .72 / 1.35 |
| Club | .22 / 1.75 | .35 / 1.60 | .55 / 1.65 | .35 / 1.65 | .75 / 1.30 |
| Festival | .28 / 1.90 | .35 / 1.95 | .35 / 1.85 | .65 / 1.35 | .56 / 1.65 |

Piecewise smoothstep curves join at neutral. A low setting remains alive; high
settings remain bounded. A manual selection lasts for the uninterrupted visit
across occurrences, Mood and character changes. Follow DJ clears this local bias.
Voice `motion` patches use the same normalized Dynamics state, respecting their
existing track/visit duration. A temporary track bias restores the previously held
visit choice at the next occurrence; this saved restoration value never acts as
a second speed multiplier. A newer direct slider choice replaces the override.
Hold/Undo restore the duration constraint as well as the effective value. A newer gesture invalidates an older voice turn,
even if its initial slider value equals the current thumb. Colour/depth patches
retain compatible fields. No slider event calls the network or settings route.

## Renderer, voice and lifecycle

One engine owns two cached pipelines: solid fields and additive procedural
filaments. Fixed-size scene/transition packets retain all visible weights during
rapid A→B→C→A. Animation phases integrate bounded monotonic frame deltas; speed
changes never multiply elapsed wall time. Pausing discards elapsed background
time. Reduce Motion applies a static target without phase advance. No runtime
pipeline compilation, CPU mesh generation or particle-list growth occurs.

GPU pressure, thermal/low-power state and simultaneous-world transition work
reduce sampling/resolution/FPS independently of Dynamics. Festival keeps a hard
12,288-point ceiling; reduced sampling spans the same full sculpture. Up to three
submitted command buffers can finish after withdrawal; no new work is submitted
once inactive/dismantled, and stale completions cannot acknowledge another visit. The neutral canvas draws once and pauses until its inputs change.

Voice captures only the original authenticated owner/Session/source, confirmed
persona and Mood revisions, occurrence, scene ticket and original lease deadline.
A revalidation read can reject a same-item replay; it cannot extend that deadline.
Without a confirmed persona, visual voice is disabled and neutral visits reject directives. A CPU parse/application does not earn success: the exact final target must settle
and complete on the GPU first. Only then does the short glass confirmation show.
Cancelled/failed turns consume the same continuous-visit attempt budget even
when a revoked server-visit ID is rotated. Canvas contact remains temporary in every family: liquid dents in Home, torque
and local light on Radio's metal, controlled light over Club's rigid architecture,
and coherent filament displacement/glow in Festival. Strong taps exceed swipes;
all contact state expires without a style mask. No ordinary Ask DJ, music, queue,
volume, Mood/Persona/Presence write, transcript history, analytics or durable
visual preference is introduced.

## Qualification

See [the evidence report](../feedback/APPLE_VIBESCAPE_FAMILIES_20261102.md).
The reproducible native probe is `Tools/qualification/vibescape/FamilyMetalProbe.swift`. It additionally requires actual GPU pixel differences for palette, depth, material roughness and deformation in all four families (16 checks), so accepting a field cannot silently leave that family unchanged.
Physical installation, provider occurrences, real authorized STT/voice commands,
energy/thermal measurements, VoiceOver and final artistic approval are separate
acceptance activities. Green fixtures or offscreen GPU timings do not grant them.
