# Release And Live Validation

This checklist tracks work that cannot be completed by source changes alone.

## Signing

- Set `DEVELOPMENT_TEAM` in `project.yml` or an ignored local Xcode config.
- Regenerate `DJConnectApp.xcodeproj` with `xcodegen generate`.
- Confirm bundle identifiers:
  - `nl.pcvantol.djconnect.ios`
  - `nl.pcvantol.djconnect.mac`
- Archive with automatic signing enabled for the selected Apple team.

## TestFlight

- Archive the `DJConnectIOS` scheme in Release configuration.
- Upload through Xcode Organizer or `xcrun altool`/Transporter.
- Verify Local Network and Microphone permission prompts on a physical iPhone.
- Run pairing against a real Home Assistant `djconnect` setup before inviting
  external testers.

## macOS Notarization

- Archive the `DJConnectMac` scheme in Release configuration.
- Export a Developer ID signed app or disk image.
- Submit for notarization with `xcrun notarytool`.
- Staple the accepted ticket and verify Gatekeeper launch on a clean Mac user.

## Live HA Validation

Use a Home Assistant instance with the matching `djconnect` integration.

- Pair from the app-generated code and confirm HA creates the app device.
- Confirm HA entities/status sync for paired, stale, backend unavailable, and
  update-required states.
- Load backend devices through the `devices` command and switch output.
- Load queue through the `queue` command.
- Load playlists through the `playlists` command.
- Start a playlist through `start_playlist`.
- Start liked songs through `start_liked_proxy`.
- Record Push-to-Talk and verify WAV upload to `/api/djconnect/voice`.
- Copy diagnostics export and confirm no bearer token, pairing code, or query
  token appears.

## UI Test Automation

The source tree can only provide deterministic unit tests without a HA fixture.
For end-to-end UI tests, provide either:

- a real HA URL plus test integration credentials on the local network; or
- a recorded/mock HA server that implements `/api/djconnect/pair`,
  `/api/djconnect/status`, `/api/djconnect/command`, and
  `/api/djconnect/voice`.

Once that fixture exists, add XCUITests for pairing, output selection, queue,
playlist/liked proxy, voice upload, stale auth, and backend unavailable states.
