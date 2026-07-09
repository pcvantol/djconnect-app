# DJConnect App Agent Instructions

This repository follows the canonical DJConnect design foundation in
`pcvantol/djconnect`.

Before making product, UX, API, data model, prompt, release, CI,
security/privacy, public contract, architecture, or cross-repo protocol changes,
read:

1. `pcvantol/djconnect/DJCONNECT_CONSTITUTION.md`
2. `pcvantol/djconnect/PRODUCT_VISION.md`
3. `pcvantol/djconnect/DESIGN_PRINCIPLES.md`
4. `pcvantol/djconnect/ARCHITECTURE_PRINCIPLES.md`
5. `pcvantol/djconnect/CI_CD_RELEASE_GOVERNANCE.md`
6. `pcvantol/djconnect/SYNC_PROMPTS.md`
7. `pcvantol/djconnect/PRODUCT_ROADMAP.md`
8. `pcvantol/djconnect/INNOVATION_LAB.md`

## Role

This repo is the Apple first-party DJConnect intelligence client and renderer
for iOS, iPadOS, watchOS, and macOS.

It should expose DJConnect platform capabilities according to Apple platform
strengths, but must not fork the product model or implement backend-specific
intelligence locally.

## Rules

- The Constitution wins when prompts, issues, implementation details, or
  repository-specific documents conflict.
- Clients render platform capabilities; they do not own durable intelligence.
- Everything personal belongs to a DJConnect Profile in the backend.
- Device-local state is limited to hardware/client/runtime/UI concerns.
- Everything playback/provider-specific belongs to the Music Backend.
- Ask DJ history, Music DNA, recommendations, response style, likes/dislikes,
  mood, and conversation memory are profile-bound.
- Personal devices are profile-first; shared devices are room/household-first.
- VibeCast, Track Insight, Discover, Music DNA, recommendations, and Ask DJ use
  backend-owned contracts.
- Apple-specific behavior should be platform presentation, not product model
  divergence.
- Do not invent or store canonical local recommendations, Music DNA, insight
  facts, recommendation history, or Ask DJ history that should come from the
  backend.
- Secrets, tokens, personal Music DNA, personal Ask DJ history, private URLs,
  and private profile data must not leak into commits, logs, diagnostics,
  screenshots, release artifacts, guest pages, or shared devices.

## Cross-repo changes

If this repository changes pairing, device identity, VibeCast rendering, Ask DJ
contract, Music DNA/profile behavior, push handling, diagnostics, release
outputs, CI/release behavior, public contracts, or user-facing product
positioning, update `pcvantol/djconnect/SYNC_PROMPTS.md` and the relevant
roadmap/design/architecture/governance docs when needed.
