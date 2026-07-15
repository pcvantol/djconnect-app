# DJConnect App Agent Instructions

## DJConnect Platform Bootstrap

For a clean Codex/AI-agent session in this repository, start here:

`BOOTSTRAP.md`

That canonical bootstrap points back to the canonical platform foundation in
`pcvantol/djconnect` and then returns to the repository-specific rules in
this file. This repository extends the DJConnect Platform Foundation. It
does not redefine it.

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
