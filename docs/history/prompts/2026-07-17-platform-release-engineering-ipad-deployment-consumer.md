# iPad internal deployment consumer qualification

- **Prompt ID:** `APPLE-IPAD-INTERNAL-DEPLOYMENT-CONSUMER-001`
- **Title:** Add the manifest-bound iPad internal deployment consumer
- **Generation:** 2
- **Engineering program:** Platform Release Engineering
- **Branch:** `codex/add-ipad-internal-release-consumer`
- **Commit SHA:** Pending implementation commit
- **Pull request:** Pending reviewable pull request
- **Decision:** `IPAD_INTERNAL_DEPLOYMENT_CONSUMER_REVIEWABLE`

## Validation summary

The Apple Release Version Integrity and Apple Build Engineering qualifications
are merged. The approved central 3.3.0 manifest contains an iPad artifact
binding but repository evidence showed no iPad-specific consumer: the generic
Apple relay is MacBook-only and the iPhone relay requires a paired Watch.

This increment adds a standalone iPad relay and smoke workflow. Both fail
closed on the exact source candidate, manifest ID, artifact identity and SHA-256.
The relay requires a connected physical iPad with Developer Mode enabled,
locally re-signs only for that iPad, and removes the embedded Watch companion.
The smoke workflow checks the installed `dev.djconnect.ios` bundle against the
manifest version. Shell and workflow syntax and repository source tests are
run before review.

## Created artifacts

- `.github/workflows/apple-ipad-secure-distribution-relay.yml`
- `.github/workflows/apple-ipad-post-deployment-smoke.yml`
- This immutable Prompt History record.

## Updated artifacts

- `Tools/release/resign_internal_ios_bundle.sh`
- `docs/RELEASE.md`
- `tests/DJConnectCoreTests/DJConnectCoreTests.swift`
- Rolling engineering, repository, management and prompt records.

## Known limitations

- `DJCONNECT_APPLE_IPAD_UDID` must be configured in the protected
  `apple-secure-distribution` environment after merge; its value is never
  stored in this repository.
- A physical iPad must be connected to the macOS runner and have Developer
  Mode enabled at dispatch time.
- The consumer does not authorize or dispatch a release.

## Deferred work

- Obtain target-specific owner authorization for the existing iPad 3.3.0
  manifest binding after the consumer is merged and configured.
- Run manifest-bound deployment and separately authorized post-deployment
  smoke only after that authorization.

## Recommended next prompt

Configure the protected iPad UDID environment secret, then obtain the exact
iPad deployment authorization. Do not start deployment automatically.
