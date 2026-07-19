# DJConnect App Engineering Status

Status: iPad release-asset download repair merged

Repository: `pcvantol/djconnect-app`

## Reconciled Engineering State

PR #38, `fix: retrieve iPad release asset through GitHub API`, merged into
`main` on 2026-07-17. Its authoritative merge commit is
`30ed05d2c0fb2b683ec789f97e0803271006d7a7`.

The merged repair retrieves the exact manifest-bound iPad release asset through
the GitHub Releases API using the existing scoped `PUBLIC_RELEASES_TOKEN` and
retains SHA-256 verification. It did not change the manifest, artifact,
signing scope, device selection or authorization.

## Reconciled Decision

Decision: `IPAD_RELEASE_ASSET_DOWNLOAD_REPAIRED_MERGED`.

The predecessor is `MERGED`; no repair implementation remains active. The
separately authorized iPad deployment may be retried only under its existing
authorization. No deployment or smoke action is started by this reconciliation.
