# Apple Profile Adoption Report

Epic 3B Phase 2 adopts the canonical Home Assistant Profile Platform contract in
the shared Apple client contract layer. Apple remains the reference renderer;
Home Assistant remains authoritative for Profile resolution, Music DNA,
recommendations, Ask DJ history, mood persistence, household state, identity and
music backend routing.

## Implemented

- Added `DJConnectProfileContext`, request source values, resolved-profile
  response metadata and typed Profile Platform errors.
- Extended shared JSON request wrapping so profile-aware POST bodies can include
  only canonical fields: `profile_id`, `session_id`, `private_session`,
  `request_source`, `device_id`, and `client_type`.
- Added profile context support to Ask DJ, commands, Music DNA, Discover, Track
  Insight, HTTP Discover feed requests, and raw voice upload headers.
- Decoded canonical response metadata where available: `profile_id`,
  `music_dna_key`, `resolved_profile`, and `resolution`.
- Classified structured Profile Platform failures without treating them as
  stale auth: `profile_required`, `invalid_profile`, `device_not_mapped`,
  `profile_backend_missing`, `profile_music_account_missing`,
  `profile_backend_account_mismatch`, `profile_access_denied`,
  `private_session_restriction`, `invalid_client_type`, and
  `invalid_request_context`.
- Updated iOS/macOS UI error handling and watch proxy messaging to present
  profile repair/setup failures gracefully.
- Added canonical Profile context fixtures and tests for contract decoding,
  request generation, private sessions, typed errors, and watchOS identity
  parity.
- Updated README and architecture docs to describe Apple as the reference
  Profile-aware client.

## Deferred

- Profile CRUD, household management, profile export/import UI, music account
  linking, backend resolver logic, and music backend logic remain out of scope
  and backend-owned.
- Rich Profile switching UI is not introduced here. The shared contract layer is
  ready for explicit `profile_id` selection once Home Assistant exposes the
  selected/current Profile state to clients.
- Full cache key migration is not completed in this pass. Existing local caches
  remain rendering caches; profile-scoped cache storage should be completed when
  explicit Profile switching UI lands.
- WebSocket profile context threading is partly covered by payload models, but
  fast-path top-level profile fields should be audited again once backend
  capabilities advertise Profile Platform routes in live deployments.

## Backend Assumptions

- Home Assistant supports Profile context contract version `1` on the existing
  `/api/djconnect/v1` surface.
- `djconnect/capabilities` advertises Profile Platform support through
  `capabilities.profiles`, `capabilities.private_sessions`,
  `capabilities.request_context`, and `contract_versions.profile_context`.
- Home Assistant resolves Profile context from explicit `profile_id`, device
  mapping, HA user hint, room/area mapping, fallback Profile, or structured
  Profile error.
- Private Session policy is enforced by Home Assistant. Apple sends the signal
  and avoids claiming ownership of persistence behavior.
- `music_dna_key` values scoped as `profile:<profile_id>` are backend-provided
  and should not be synthesized from local client state.

## Client Observations

- The shared Swift model layer is the right adoption point. iOS, macOS and
  watchOS all benefit from one contract model instead of platform-specific
  Profile logic.
- Existing WatchConnectivity payloads already preserve watchOS `device_id` and
  `client_type`; adding profile context to shared payloads keeps watchOS parity.
- Local UI cache behavior is intentionally performance-oriented, but explicit
  Profile switching will require cache keys that include Profile identity and
  private-session non-persistence rules.
- Existing tests are broad and useful, but the full suite currently has
  unrelated/flaky failures outside the Profile fixture suite.

## Windows Recommendations

- Reuse the same canonical request envelope and error mapping. Do not invent
  Windows-specific Profile fields.
- Centralize Profile context in one networking/request wrapper before touching
  feature screens.
- Preserve `device_id` and `client_type:"windows"` on every personal-state
  request, and add explicit `profile_id` only when Windows offers Profile
  switching.
- Treat structured Profile errors as repair/setup states, not generic auth
  failures.
- Key local caches by resolved Profile once Windows supports switching, and
  avoid durable writes for Private Session results.

## Verification

- `swift test --filter DJConnectClientContractFixtureTests` passes.
- Full `swift test` compiles and runs, but failed with existing unrelated
  localization/async/pairing-recorder issues during this pass.
