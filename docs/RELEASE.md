# Release And Live Validation

This checklist tracks work that cannot be completed by source changes alone.

## iOS Signing Requirements

Before an iOS/TestFlight release, make sure these are available:

- An active Apple Developer Program membership.
- Access to the Apple team that owns the app identifier.
- Xcode signed in with that Apple ID.
- Bundle identifier `nl.pcvantol.djconnect.ios` registered in Apple Developer
  Certificates, Identifiers & Profiles.
- App Store Connect app record for `DJConnect` using the same bundle
  identifier.
- A physical iPhone or iPad on the local network for Local Network,
  Microphone, and Speech Recognition permission validation.

## iOS Signing Steps

1. Set `DEVELOPMENT_TEAM` for local release builds. Prefer an ignored local
   Xcode config if multiple developers use different teams; otherwise set it in
   `project.yml`.
2. Run `xcodegen generate` after changing signing settings.
3. Open `DJConnectApp.xcodeproj` in Xcode.
4. Select the `DJConnectIOS` target.
5. Confirm Signing & Capabilities uses automatic signing and the expected team.
6. Confirm bundle identifier `nl.pcvantol.djconnect.ios`.
7. Run the app on a physical iPhone/iPad and accept Local Network, Microphone,
   and Speech Recognition prompts.
8. Pair against a real Home Assistant `djconnect` setup and validate playback,
   queue, playlists, output switching, and voice/PTT.
9. Select Any iOS Device or a physical device destination.
10. Archive with Product > Archive in Release configuration.
11. Upload through Xcode Organizer or Transporter to TestFlight.
12. In App Store Connect, wait for processing, complete beta compliance, and
    assign internal or external testers.

## macOS Signing

- Set `DEVELOPMENT_TEAM` in `project.yml` or an ignored local Xcode config.
- Regenerate `DJConnectApp.xcodeproj` with `xcodegen generate`.
- Confirm bundle identifier `nl.pcvantol.djconnect.mac`.
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

The `DJConnectIOSUITests` target now launches the iOS app in deterministic
`--uitesting` mode with isolated defaults and a mock Home Assistant URL. Extend
that target with a real mock server fixture for pairing, output selection,
queue, playlist/liked proxy, voice upload, stale auth, and backend unavailable
states.
