# Third-Party Notices

DJConnect is built from the app source in this repository and Apple platform
SDK frameworks. The repository currently does not declare external runtime
Swift package dependencies in `Package.swift` or external Xcode package
dependencies in `project.yml`.

The DJConnect app source in this repository is distributed under the MIT
License. See [LICENSE](../LICENSE).

Release builds still run the third-party update preflight before compiling
artifacts. If that preflight upgrades or resolves dependency versions, update
this file in the same change as:

- `docs/TECHNICAL_DESIGN_DECISIONS.md`
- `CHANGELOG.md`
- English and Dutch release notes for the shipped version, if maintained
  separately from `CHANGELOG.md`

## Runtime Libraries And Frameworks

| Component | Purpose | License / Terms |
| --- | --- | --- |
| Swift Standard Library | Swift runtime support | Swift project license and runtime library exception |
| Apple SDK frameworks | iOS and macOS app runtime, UI, media, networking, security, logging and diagnostics | Apple Developer Program License Agreement and SDK terms |

## Build And Release Tooling

| Tool | Purpose | License / Terms |
| --- | --- | --- |
| Xcode / xcodebuild / xcrun | Build, archive, export, signing and notarization tooling | Apple Developer tools terms |
| Swift Package Manager | Swift package resolution and test/build orchestration | Swift project license |
| Git | Source control | Git license |
| GitHub CLI | Release creation and artifact upload | GitHub CLI license |
| Homebrew-managed tools, when installed locally | Optional release helper tooling such as `swiftlint`, `xcbeautify`, `create-dmg`, and `mas` | Tool-specific licenses |

## Release Maintenance

`Tools/release/update_thirdparty.sh` records the tool versions used for the
release in `build/release/thirdparty-update-report.txt`. When dependency
versions change, the release preflight exits before publishing unless the
notices, localized release notes, and release documentation have been reviewed
and updated.
