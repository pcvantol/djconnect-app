# Adaptive headphone app icon source

The foreground is imported without modification from the owner's referenced
ESP32 purple/magenta headphone. `provenance.json` pins the exact protected Git
revision, source file and SHA256. The PNG is stored inside the native
`Apps/Shared/AppIconAdaptive.icon/Assets` directory. The Watch-only document
`Apps/Shared/AppIconWatchAdaptive.icon` contains an identical, hash-checked
foreground with an opaque black background in both default and dark appearances.
The separate document scopes the black background to the Watch target.

The native document controls padding, separate outer background fills and
system appearance rendering. The original navy center belongs to the foreground
artwork; it is not the retired blue glass tile. No new image generation or
wordmark rendering is involved. Xcode compiles the document for the app targets;
`GenerateAppIcon.swift` continues to describe only the retained legacy catalogs.

Validate with `python3 Tools/validate_brand_assets.py`. Native compiler/render
results and their scope are recorded in
`docs/feedback/APPLE_ADAPTIVE_HEADPHONE_ICON_20261021.md`.
