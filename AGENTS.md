# DJConnect Agent Guidance

This repository follows the DJConnect design foundation maintained in `pcvantol/djconnect`.

Before changing product behavior, architecture, public contracts, release behavior, security/privacy behavior, or cross-repo protocol, read the source-of-truth documents in the Home Assistant integration repo:

1. `DJCONNECT_CONSTITUTION.md`
2. `PRODUCT_VISION.md`
3. `DESIGN_PRINCIPLES.md`
4. `ARCHITECTURE_PRINCIPLES.md`
5. `CI_CD_RELEASE_GOVERNANCE.md`
6. `PRODUCT_ROADMAP.md`
7. `INNOVATION_LAB.md`
8. `SYNC_PROMPTS.md`

## Operating rules

- The Constitution wins when prompts or issues conflict.
- No client owns product features; clients render platform capabilities.
- Persistent intelligence belongs in the Home Assistant integration/backend.
- Everything personal belongs to a DJConnect Profile.
- Everything hardware/client-specific belongs to a Device.
- Everything playback/provider-specific belongs to the Music Backend.
- Do not store canonical Music DNA, recommendation history, or Ask DJ history only in the client.
- Personal devices are profile-first; shared devices are room/household-first.
- Secrets, tokens, personal Music DNA, and personal Ask DJ history must not leak into logs, diagnostics, release artifacts, guest pages, or shared devices.

## Repository role

`pcvantol/djconnect-app` is the Apple first-party intelligence client and renderer for iOS, iPadOS, watchOS, and macOS.

It should expose DJConnect platform capabilities according to Apple platform strengths, but must not fork the product model or implement backend-specific intelligence locally.

## Cross-repo changes

If this repository changes pairing, device identity, VibeCast rendering, Ask DJ contract, Music DNA/profile behavior, push handling, diagnostics, release outputs, or user-facing product positioning, update `pcvantol/djconnect/SYNC_PROMPTS.md` and the roadmap/design docs when needed.
