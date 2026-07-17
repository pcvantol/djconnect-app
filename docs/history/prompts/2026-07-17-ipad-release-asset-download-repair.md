# iPad release-asset download repair

- **Prompt ID:** `APPLE-IPAD-RELEASE-ASSET-DOWNLOAD-REPAIR-001`
- **Title:** Repair manifest-bound iPad release-asset retrieval
- **Generation:** 2
- **Engineering program:** Platform Release Engineering
- **Branch:** `codex/fix-ipad-release-asset-download`
- **Commit SHA:** Pending implementation commit
- **Pull request:** Pending reviewable pull request
- **Decision:** `IPAD_RELEASE_ASSET_DOWNLOAD_REPAIRED`

## Validation summary

PR #37 merged the iPad deployment consumer. The authorized deployment passed
the exact physical iPad, Developer Mode, manifest and signing-identity checks.
It failed before artifact verification, signing or installation because direct
browser retrieval of the manifest asset returned HTTP 404 on the self-hosted
runner, despite the release and its checksum existing.

The repair retrieves the exact `ios/v<release-version>` asset through `gh
release download` with the existing scoped `PUBLIC_RELEASES_TOKEN`, verifies
its SHA-256 as before, and leaves all later deployment gates unchanged.

## Created artifacts

- This immutable Prompt History record.

## Updated artifacts

- `.github/workflows/apple-ipad-secure-distribution-relay.yml`
- `docs/RELEASE.md`
- `Tests/DJConnectCoreTests/DJConnectCoreTests.swift`
- Rolling engineering, repository, management and prompt records.

## Known limitations

- The repair must merge before retrying the already authorized deployment.
- No deployment or smoke is initiated by this increment.

## Deferred work

- Retry the existing authorized iPad deployment after the repair merges.
- Obtain separate post-deployment smoke authorization only after deployment
  succeeds.

## Recommended next prompt

Execute the already authorized iPad deployment after merge and request smoke
authorization on successful deployment evidence.
