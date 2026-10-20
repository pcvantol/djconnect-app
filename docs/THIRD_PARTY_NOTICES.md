# Third-Party Notices

DJConnect is built from the app source in this repository and Apple platform
SDK frameworks. VibeCast destination encryption uses JOSESwift 3.0.0, pinned in
both `Package.swift` and `project.yml` to immutable revision
`c2664a902e75c0426a1d43132bd4babc6fd173d3`. Its upstream Apache License 2.0
text is bundled in DJConnectCore and available in the native Legal → OSS view.
This dependency is source preparation, not genuine SDK/runtime acceptance.

The DJConnect app source in this repository is distributed under the MIT
License. See [LICENSE](../LICENSE).

Release builds still run the third-party update preflight before compiling
artifacts. If that preflight upgrades or resolves dependency versions, update
this file in the same change as:

- `docs/TECHNICAL_DESIGN_DECISIONS.md`
- `CHANGELOG.md`
- localized release notes for the shipped version (`en`, `nl`, `de`, `fr`,
  `es`), if maintained separately from `CHANGELOG.md`

## Runtime Libraries And Frameworks

| Component | Purpose | License / Terms |
| --- | --- | --- |
| JOSESwift 3.0.0 | RFC7516 RSA-OAEP-256 / A256GCM destination encryption; no algorithm negotiation or custom primitives | Apache License 2.0; copyright 2024 Airside Mobile Inc.; [bundled license](../Sources/DJConnectCore/Resources/ThirdParty/JOSESwift-LICENSE.txt) |
| Swift Standard Library | Swift runtime support | Swift project license and runtime library exception |
| Apple SDK frameworks | iOS and macOS app runtime, UI, media, networking, security, logging and diagnostics | Apple Developer Program License Agreement and SDK terms |

## Build And Release Tooling

| Tool | Purpose | License / Terms |
| --- | --- | --- |
| Xcode / xcodebuild / xcrun | Build, archive, export, signing and notarization tooling | Apple Developer tools terms |
| Swift Package Manager | Swift package resolution and test/build orchestration | Swift project license |
| Git | Source control | Git license |
| GitHub CLI | Release creation and artifact upload | GitHub CLI license |
| GitHub CodeQL Action `4.38.0` | C/C++ security analysis for tracked firmware source; pinned by immutable commit in the workflow and not distributed with the app | Upstream license and notices |
| Homebrew-managed tools, when installed locally | Optional release helper tooling such as `swiftlint`, `xcbeautify`, `create-dmg`, and `mas` | Tool-specific licenses |

## Release Maintenance

`Tools/release/update_thirdparty.sh` records the tool versions used for the
release in `build/release/thirdparty-update-report.txt`. When dependency
versions change, the release preflight exits before publishing unless the
notices, localized release notes, and release documentation have been reviewed
and updated.

## Inter 4.1 in Brand V2 graphics

Brand V2 wordmarks contain outlined Inter lettering, copyright 2016 The Inter
Project Authors, licensed under the SIL Open Font License 1.1. No font binary is
shipped. Full license and upstream provenance: [license](../Tools/IconSource/BrandV2/LICENSE.txt)
and [provenance](../Tools/IconSource/BrandV2/PROVENANCE.md).
