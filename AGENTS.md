# DJConnect App Agent Instructions

This repository follows the canonical DJConnect design foundation in `pcvantol/djconnect`.

Before making product, UX, API, data model, prompt, release or CI changes, read:

1. `pcvantol/djconnect/DJCONNECT_CONSTITUTION.md`
2. `pcvantol/djconnect/PRODUCT_VISION.md`
3. `pcvantol/djconnect/DESIGN_PRINCIPLES.md`
4. `pcvantol/djconnect/ARCHITECTURE_PRINCIPLES.md`
5. `pcvantol/djconnect/SYNC_PROMPTS.md`
6. `pcvantol/djconnect/PRODUCT_ROADMAP.md`
7. `pcvantol/djconnect/INNOVATION_LAB.md`

## Role

This repo is the Apple first-party DJConnect intelligence client and renderer for iOS, iPadOS, watchOS and macOS.

## Rules

- Clients render platform capabilities; they do not own durable intelligence.
- Everything personal belongs to a DJConnect Profile in the backend.
- Device-local state is limited to hardware/client/runtime/UI concerns.
- Ask DJ history, Music DNA, recommendations and response style are profile-bound.
- VibeCast, Track Insight, Discover and Ask DJ use backend-owned contracts.
- Apple-specific behavior should be platform presentation, not product model divergence.
- Do not invent local recommendations, Music DNA or insight facts that should come from the backend.

## Cross-repo changes

If a client change requires backend contract changes, update `pcvantol/djconnect/SYNC_PROMPTS.md` and the relevant design/architecture docs first.
