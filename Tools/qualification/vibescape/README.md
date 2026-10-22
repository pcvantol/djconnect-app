# Native offscreen VibeScape GPU probe

Build from the repository root using Xcode's installed Metal Toolchain. Choose a
fresh private output directory. No app launch, pairing, microphone, Profile,
backend call or user image is involved. Example:

```sh
mkdir -p /tmp/djc-vibescape-gpu
xcrun -sdk macosx metal -c Sources/DJConnectUI/VibeScapeShaders/VibeScape.metal -o /tmp/djc-vibescape-gpu/scene.air
xcrun -sdk macosx metallib /tmp/djc-vibescape-gpu/scene.air -o /tmp/djc-vibescape-gpu/scene.metallib
swiftc -parse-as-library Sources/DJConnectUI/VibeScapeScene.swift Sources/DJConnectUI/VibeScapeMetalEngine.swift Tools/qualification/vibescape/MetalProbe.swift -o /tmp/djc-vibescape-gpu/probe
/tmp/djc-vibescape-gpu/probe /tmp/djc-vibescape-gpu/scene.metallib /tmp/djc-vibescape-gpu/output
```

Twenty scene PNGs, four Dynamics comparison PNGs and `gpu-report.json` describe synthetic native shader output and GPU
command timings only. They do not establish UI lifecycle, voice correctness,
physical iPhone/iPad quality, whole-app FPS, thermal/battery or user acceptance.
See `docs/VIBESCAPE_APPLE_PREVIEW.md` for the closed production boundary.

The Dynamics regression fixes composition and palette, renders the two slider
extremes at an identical clock and after three seconds, and fails if static
pixels do not differ or intense motion does not exceed calm motion. The report
includes mean absolute byte deltas. This does not exercise native touch input.
