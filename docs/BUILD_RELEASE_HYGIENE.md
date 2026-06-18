# Build And Release Hygiene

DJConnect releases run a third-party update preflight before build/archive work.

## Third-Party Update Preflight

`./release.sh` invokes `Tools/release/update_thirdparty.sh` unless
`DJCONNECT_SKIP_THIRDPARTY_UPDATE=1` is set.

The preflight:

- records Xcode, Swift, Git, GitHub CLI, notarytool, and Homebrew versions in `build/release/thirdparty-update-report.txt`;
- runs `swift package update` for every `Package.swift`;
- runs `xcodebuild -resolvePackageDependencies` for every `.xcodeproj`;
- updates Homebrew metadata and upgrades installed release helper tools before compiling artifacts.

## Tool Upgrades

Use this for a full local release hygiene pass:

```sh
./release.sh <X.Y.Z>
```

Homebrew-managed tools are upgraded only if installed locally. The script never installs new tools by itself.
Use `DJCONNECT_SKIP_SYSTEM_TOOL_UPGRADE=1` only for emergency local validation
when Homebrew or a tool registry is unavailable.

## Notice And Documentation Gate

When `Package.resolved` changes, the preflight exits before publishing unless
`DJCONNECT_ALLOW_THIRDPARTY_NOTICE_DRIFT=1` is set.

Only set that variable after updating:

- `docs/THIRD_PARTY_NOTICES.md`
- `docs/TECHNICAL_DESIGN_DECISIONS.md`
- `CHANGELOG.md`
- English and Dutch release-note Markdown for the exact app version, when the
  public What's New copy differs from `CHANGELOG.md`
- GitHub release notes for the exact app version

This keeps shipped binaries, localized release notes, and legal notices in sync.

## Emergency Skip

`DJCONNECT_SKIP_THIRDPARTY_UPDATE=1` may be used only when the package registry or local toolchain is unavailable. Add a follow-up issue before publishing a production release.
