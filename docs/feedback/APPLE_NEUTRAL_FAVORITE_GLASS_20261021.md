# Neutral favorite glass

Local successor to `f60f12b`. FavoriteTrackButton now uses a clear glass tint
for both favorite states, removing its explicit selected-state accent tint.
The white filled/outline heart still communicates favorite status. The shared
component supplies both the session header and Now Playing on iOS and macOS.
Native glass interaction, circle shape, accessibility labels, capability gates,
favorite actions and reduced-transparency fallback remain unchanged.

Validation: isolated unsigned iOS Simulator build-for-testing completed with
exit 0 / TEST BUILD SUCCEEDED. Native macOS DJConnectUI build completed with
exit 0 in 27.10 seconds. git diff --check passed. No physical-device visual
acceptance, installation or publication is claimed.

Build logs and SHA-256:

- `/private/tmp/djc-neutral-favorite-glass-20261021-ios.log`:
  `bd3ec2d16a7b1cd96580d9d520c49e77a6d824bf952b91b3a351a532ba9f6fcf`
- `/private/tmp/djc-neutral-favorite-glass-20261021-mac.log`:
  `2499a6472426ff7823deb90268a252caec271f9aadacad4e326d10b149cb7598`
