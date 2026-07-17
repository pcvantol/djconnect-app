# DJConnect Repository Status

Status: Active engineering repository

## Repository

`pcvantol/djconnect-app`

## Role

Apple Intelligence Client UX for iOS, iPadOS, macOS and watchOS.

## Ownership

Owns: Apple client implementation, Apple presentation/runtime behavior and localized rendering for Apple surfaces.

Does not own: backend intelligence, Music DNA storage, Spotify OAuth secrets, central relay logic, canonical Profile resolution or foundation docs.

## Current Phase

iPad internal deployment consumer qualification.

This phase adds a manifest-bound internal iPad deployment relay and a separate
post-deployment smoke consumer. It does not dispatch a release, change a
release manifest, modify application functionality, or change the platform
architecture.

## Status

Reviewable.

## Blocking Dependencies

- `DJCONNECT_APPLE_IPAD_UDID` must be configured as a protected
  `apple-secure-distribution` environment secret after merge.
- A physical iPad with Developer Mode enabled must be connected to the
  self-hosted macOS runner when deployment is authorized.
- A separate exact owner authorization for the iPad artifact binding is
  required before dispatch; this increment does not provide it.

## Current Prompt

iPad internal deployment consumer qualification

## Completion Report

The iPad relay/smoke workflows, `docs/RELEASE.md`, repository tests, and an
immutable Prompt History record.

## Last Qualification

The manifest contains the iPad 3.3.0 artifact binding, but the repository has
no iPad-specific deployment or smoke consumer. The pre-existing generic Apple
relay is deliberately MacBook-only and the iPhone relay requires a paired
Watch, so neither can be used for iPad.

## Validated Base SHA

`4d4020837766e3616361cae0b2c069e55371297f`

The completion record captures the exact implementation commit.

## Repository-Local Next Action

Review and merge PR #37. Then configure the iPad environment
secret and wait for the target-specific operational authorization before any
deployment dispatch.

## Notes

Apple verification phases are governed by pcvantol/djconnect/PROMPT_INDEX.md; this repository prompt index must stay repository-local.
