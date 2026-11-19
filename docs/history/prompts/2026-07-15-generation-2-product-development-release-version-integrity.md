# Prompt History: Restore Apple Release-Version Integrity

Status: immutable completion record

## Prompt ID

`G2-PD-APPLE-VERSION-001`

## Prompt Title

Product Development: Restore Apple release-version integrity

## Generation

Generation 2

## Engineering Program

Product Development

## Branch

`codex/restore-apple-release-version-integrity`

## Commit SHA

`ec49442e316d8dda959d1d562c447c7e95449577`

## Pull Request

[#24](https://github.com/pcvantol/djconnect-app/pull/24)

## Decision

Apple `app_version` is now derived from `CFBundleShortVersionString`; build
metadata is derived from `CFBundleVersion`; and `protocol_version` is explicit
and independent. The existing `firmware` field remains populated with the same
protocol value for Home Assistant compatibility.

## Validation Summary

- Verified `project.yml` and the iOS, macOS and watchOS Info.plists define
  release and build values from `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION`.
- Passed `statusRequestIncludesContractFieldsAndHeaders` and
  `appleReleaseVersionIntegrityUsesBundleMetadataAndIndependentProtocolMetadata`.
- Passed unsigned `DJConnectMac` and `DJConnectWatch` builds.
- Static source validation found no remaining `appVersion = protocolVersion`
  coupling or hardcoded Apple application-release fallback.

## Created Artifacts

- This immutable Prompt History record.

## Updated Artifacts

- `Sources/DJConnectCore/DJConnectModels.swift`
- `Sources/DJConnectCore/DJConnectClient.swift`
- `Sources/DJConnectUI/DJConnectAppModel.swift`
- `Sources/DJConnectUI/DJConnectLaunchView.swift`
- `Apps/DJConnectWatch/DJConnectWatchModel.swift`
- `Apps/DJConnectWatch/DJConnectWatchRootView.swift`
- `Tests/DJConnectCoreTests/DJConnectCoreTests.swift`
- `README.md`
- `docs/API_CONTRACT.md`
- `ENGINEERING_STATUS.md`, `REPOSITORY_STATUS.md`,
  `MANAGEMENT_SUMMARY.md` and `PROMPT_INDEX.md`.

## Known Limitations

The iOS simulator scheme build is blocked before compilation by a pre-existing
Xcode output collision: `DJConnectIOS` and `DJConnectWatch` both produce
`DJConnect.app` in the same simulator products directory.

## Deferred Work

Resolve the iOS/Watch duplicate-output project configuration in a dedicated
build-system increment. It is outside this versioning increment and was not
changed.

## Recommended Next Prompt

Generation 2 Build Engineering: resolve the iOS/Watch duplicate-output project
configuration, then validate an unsigned iOS simulator build. Do not start it
automatically.
