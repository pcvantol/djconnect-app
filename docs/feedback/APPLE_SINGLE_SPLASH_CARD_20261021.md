# One splash card

Local change based on `a06e979`: the launch banner, welcome artwork, version and
progress indicator now share one padded frosted surface. The banner's own
surface is disabled only within the splash. Its default appearance on other
screens is preserved. Existing scrolling, adaptive branding, accessibility
grouping and launch timing remain in place.

Validation completed:

- Isolated unsigned iOS Simulator build-for-testing: exit 0, TEST BUILD SUCCEEDED.
- Native macOS DJConnectUI target build: exit 0, completed in 31.43 seconds.
- git diff --check: passed.

No runtime visual qualification, device installation or publication performed.

Build logs and SHA-256:

- `/private/tmp/djc-single-splash-card-20261021-ios.log`:
  `eb12ce0a560789356b44a2236cbf8f64f24c57203722317a1ef8026c8c88b1f8`
- `/private/tmp/djc-single-splash-card-20261021-mac.log`:
  `fd84c2dddf155230bb8ef653c4acf1aa83890d5c82505df47f62ca02ca75e6c9`
