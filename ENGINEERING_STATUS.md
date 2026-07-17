# DJConnect App Engineering Status

Status: iPad release-asset download repair in progress

Repository: `pcvantol/djconnect-app`

## Current Engineering State

The manifest-bound iPad deployment consumer merged through PR #37. Its first
authorized deployment attempts proved the physical iPad, Developer Mode,
manifest and checksum binding correctly, but failed before signing because the
browser release-asset URL returned HTTP 404 from the self-hosted runner.

The active bounded increment replaces browser URL retrieval with the GitHub
Releases API through the existing scoped `PUBLIC_RELEASES_TOKEN`. It does not
alter the manifest, artifact, signing scope, device selection or authorization.

## Current Decision

Decision pending validation: `IPAD_RELEASE_ASSET_DOWNLOAD_REPAIRED`.
Stop after one reviewable repair pull request; do not retry deployment until
the repair is merged.
