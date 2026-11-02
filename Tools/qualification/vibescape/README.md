# Native offscreen VibeScape GPU qualification

`FamilyMetalProbe.swift` uses the shipping shared engine, family curves and
presentation integrator. It renders 48 scenarios (four confirmed-character
families × four Moods × three Dynamics positions), twelve eight-second GIFs,
four shared-palette monochrome comparisons, twenty synthetic occurrence/seed
images **per family**, and 240 rapidly interrupted transition frames. The report
contains per-scenario median/p95 GPU command times and transition costs. Sixteen
field checks require visible palette/depth/material/deformation effects. Four
contact checks require visible swipe/tap reactions, a stronger tap and exact
restoration after expiry in every family.

These are explicitly synthetic scene/source inputs. They do not establish real
Spotify occurrences, paired Root operation, microphone/STT, whole-app FPS,
physical iPhone/iPad energy/thermal behaviour, VoiceOver or user acceptance.
GIFs are generated from actual Metal frames, never displayed by VibeScape.

Build the package using the repository's normal Swift qualification first.
Choose its existing products directory containing `DJConnectCore.o`,
`JOSESwift.o` and their modules, then run:

```sh
python3 Tools/qualification/vibescape/run_family_probe.py \
  --products '/path/to/the/built/package/Products/Debug' \
  --output '/Volumes/Shared Data/tmp/pcvantol/vibescape-fresh-gpu-run'
```

The destination must not exist. The runner compiles the checked-in shader once,
links the existing Core palette implementation, and records source **and linked
object** hashes. It performs no app launch, installation, pairing, Profile,
provider, model, microphone or settings operation. No ordinary `/tmp` output or
runtime texture assets are used.

`MetalProbe.swift` retains the earlier Home touch regression (positions, bounded
impulses, expiry and tap/swipe strength). Compile it with the same
`VibeScapeFamilies.swift`, `VibeScapeScene.swift`, `VibeScapeMetalEngine.swift`
and linked Core/JOSESwift products, substituting it for `FamilyMetalProbe.swift`.
Its optional fourth/fifth arguments specify width/height (64…2048).

Native AppModel/settings and actual iPhone/iPad UI qualification lives in
`../vibescape-controls/`. It remains separate from these GPU measurements.
See `docs/design/VIBESCAPE_FAMILIES_V1.md` and
`docs/feedback/APPLE_VIBESCAPE_FAMILIES_20261102.md` for reference comparison,
current evidence and outstanding device acceptance.
