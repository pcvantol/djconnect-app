# Apple Brand V2 native scale preparation — 19 October 2026

Bounded follow-up to Apple138 and
[the native preflight](APPLE_BRAND_V2_PREFLIGHT_20261019.md). This adds a reusable
offscreen qualification tool, not a shipping brand import. Core PR1224 remains
OPEN/draft at883cb9f3ff9de8ec7f5ae4c5f04f852e0d8bd866, with no merged producer
acceptance. The ordinary apps and shipping source assets were not changed.

## Input and native evidence

Actions run39299462062 candidate inner archive was checked at38523622bytes,
SHA256 `aa51cf9bd417a2009cdd3bed037f46b5424ac85869fbe3e9fbb2657b4754f977`.
Manifest SHA256 is
`73cc408e10d88aa1fb8a1be2783b9c577aec398ce3dcd54c2f997ad1425984d2`.
The original master remains
`f05fcdf4602d9c63add7799469c64060a8f13e5efa66ad6c7b762fb8273ec89f`.

All68 handoff file hashes and55 output hashes/lengths match. All46 manifest PNGs
decode through ImageIO with their declared dimensions. Earlier direct-pixel
AppKit review on white/navy/blue/purple found no obvious cut-off headset, exterior
navy rectangle or inverted wordmark. This is visual inspection of an offscreen
bitmap, not installed acceptance, accessibility qualification or a calibrated
display capture.

The new tool under Tools/qualification/brand requires an explicit producer and
manifest pin, validates the handoff binding and hashes, and writes a new scratch
directory. Ten checks passed: valid render, repeated render, equality of all five
outputs, refusal of existing output, wrong manifest, wrong producer, input/output
overlap, tampered asset, parent traversal and an escaping symbolic link. Failure
checks verify no output directory is created. The tool compiles with swiftc and
runs independently of app targets. No runtime source change requires an app
rebuild here; normal protected source checks remain required for merging it.

## Findings and remaining decisions

The scale matrix compares16/20/24/32/40pt at1×/2×/3×. Literal producer policy
uses the headset at≤40px and glass above it. Consequently, for example,24pt
uses a headset at1× but glass at2×/3×;32pt has the same inconsistency. The sheet
also shows headset throughout these logical sizes. This second policy is an
explicit review alternative, not an approved reinterpretation of Core's pixel
rule. Native adoption must resolve this before slot mapping is frozen.

The existing generator was separately copied into scratch and run with the
candidate glass1024 input. It succeeds but downscales the same glass artwork
for all slots, so a simple input replacement would ignore the micro variant.
The new tool's three opaque1024px composites use its existing flat base colours
only. All three are1024×1024 with no alpha, verified by native metadata readback.
They exclude dark overlays, tint transformation and platform masks; the real
generator outputs remain separately reviewable. They do not approve those
treatments or native catalog admission.

LaunchIcon still requires explicit handling. Existing native glass wrappers must
be checked for a doubled rim and headset-ear clipping. Primary/compact wordmarks,
five-language tagline approval and actual iOS/macOS/watchOS UI remain open.
Preserve Persona/state avatars, Spotify and album/artist artwork.

Local evidence is retained under build/qualification/brand-v2-native-candidate,
brand-v2-native-scale-review-20261019-final and brand-native-tool-checks. The tool
README documents invocation and the limits of these previews. Core protected
acceptance/finalization, atomic native import, independent review, builds,
protected merge and installed sign-off are still separate work.
