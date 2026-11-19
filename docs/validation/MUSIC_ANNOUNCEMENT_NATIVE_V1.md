# Apple music announcement V1 qualification

Consumes Core contract `docs/product/MUSIC_ANNOUNCEMENT_MOMENTS_V1.md` at
`d81b8938be58a5be8127018de1cc531785c9c650`. The selected synthetic HTTP wire
receipt is preserved in `Tests/Fixtures/music-announcement-core-d81b8938.json`.
No provider credentials or personal history are included.

## Scope

Typed admission and five-language presentation on iPhone, iPad, Mac and Watch;
original retained-entry replay and artwork preparation; narrow manual-local
Settings3 text-only exception with exact prepared family/reference validation.
Unknown schemas, mismatched occurrences/recordings/sources, expired display
grants, other families and non-local targets remain denied. Original stored
content remains usable only within its own retained/source authority.

## Validation

- Swift tests: 1,705 tests in 60 suites passed.
- Repository checks: all nine passed.
- Unsigned Debug macOS build: succeeded.
- Unsigned Debug iOS build including embedded Watch app: succeeded.
- `git diff --check`: clean.

Build/test logs are retained outside the checkout under Shared Data temporary
storage, prefix `apple-music-announcement-`. This qualifies source and compiler
compatibility, not physical-device display, audible TTS, Spotify playback,
APNs, production deployment or release installation.
