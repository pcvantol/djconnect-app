# Native Brand V2 candidate review

This macOS-only tool prepares repeatable **offscreen review**, without importing
brand assets or changing `GenerateAppIcon.swift`, shipping catalogs, localized
copy, live Persona avatars, Spotify attribution or installed apps.

First obtain the candidate archive from the producer's exact-commit handoff,
verify the **inner archive** length/SHA256 and safely extract it. This tool does
not download or extract archives. A candidate manifest/producer pin identifies
review input; it does not grant protected acceptance or rollout authority.

```sh
swift Tools/qualification/brand/RenderNativeBrandReview.swift \
  /tmp/extracted-brand-candidate \
  <expected-manifest-sha256> \
  /tmp/new-native-review-directory \
  <exact-producer-commit>
```

Use a new scratch output directory; existing paths and output within the input
tree are rejected. The tool verifies the pinned manifest, handoff producer and
manifest binding, all handoff/output hashes, output byte lengths and native PNG
decoding/dimensions before creating output. Asset paths cannot escape the input
root through parent traversal or symbolic links. The archive pin remains the
caller's responsibility; a locally modified handoff cannot prove Git provenance.
Rendering writes a unique temporary sibling directory, then renames it into
place only after every artifact succeeds. Throwing failures remove that staging
directory; an output path created concurrently is preserved and causes failure.

`native-scale-matrix.png` shows16/20/24/32/40pt at1×/2×/3× as direct output pixels.
It compares the literal Core ≤40**pixel** headset threshold (A) against the
alternative of retaining the headset at ≤40**point** logical size (B). This
exposes variant changes on Retina displays; it does not silently choose a policy.
Both alternatives are resampled from the verified canonical masters, not copies
of the producer's precomputed small PNGs. The previous per-pixel PNG review and
actual device-size/scale acceptance remain separate checks.

Three opaque1024px previews composite the transparent glass master on the
existing generator's default, dark and tinted **base colours**. They intentionally
exclude the generator's dark overlays, tint transformations and system masks.
They are composition proposals, not accepted app icons or proof of native catalog
admission. For the actual current generator treatment, run the existing generator
in a separate scratch root with a copied input and review all resulting variants.

`readback.json` records exact producer/manifest/handoff pins, verified counts,
the scale mapping alternatives and matrix SHA256. The matrix uses a deviceRGB
bitmap and opaque composites use sRGB CoreGraphics contexts. These are not
calibrated physical display captures, screenshots, or accessibility qualification.
The tool is independent of the app build and needs no server or audio operation.
