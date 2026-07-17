# DJConnect App Management Summary

Status: iPad release-asset download repair reviewable

## Decision

Replace the unreliable browser-release download in the iPad internal relay with
the authenticated GitHub Releases API route, while preserving the approved
manifest identity, checksum and local-development signing boundary.

## Scope and Outcome

PR #37's consumer and device validation are correct. The repair requires the
existing scoped `PUBLIC_RELEASES_TOKEN` and downloads the exact
`ios/v<release-version>` asset through `gh release download`; SHA-256
verification before extraction, signing and installation is unchanged.

## Known Limitation

The authorized iPad deployment remains pending until the repair merges. No
artifact has been signed or installed during the failed attempts.

## Recommended Next Prompt

Merge PR #38, retry the existing authorized iPad deployment, then request
separate post-deployment smoke authorization.
