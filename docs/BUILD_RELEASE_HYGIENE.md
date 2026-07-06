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

Before source release publication, the script fetches `origin/main`, verifies
the current `HEAD` contains that remote base, and pushes the release commit
explicitly with `git push origin HEAD:main`. Source release notes are generated
from only the matching `CHANGELOG.md` version section.

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

## Repository Hygiene

Before release, beta distribution, or a maintainer-facing workflow change:

- update `CHAT_BOOTSTRAP.md` with the current release, workflow, and repository
  status assumptions;
- add or update Dutch What's New release notes in
  `docs/release-notes/nl/vX.Y.Z.md` before publishing, so localized app screens
  do not fall back to English changelog text;
- review app-facing translations in all five supported languages (`nl`, `en`,
  `de`, `es`, `fr`) whenever UI copy, notices, errors, prompts, or release
  strings change; do not leave new keys as English fallbacks in non-English
  `.lproj/Localizable.strings` files;
- keep `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `docs/RELEASE.md`, `docs/TODO.md`, and `docs/TECHNICAL_DESIGN_DECISIONS.md`
  aligned when contribution, security, CI, signing, or release behavior changes;
- check AI-assisted workflow notes for secret, private-data, screenshot, log,
  prompt, and proprietary-material handling;
- confirm GitHub Actions workflows that can publish artifacts remain
  manual-only or explicitly gated when they require maintainer approval;
- verify the public unsigned release workflow is green after a source release,
  because static What's New publication happens after its Swift test step;
- keep Swift tests that assert localized strings deterministic by setting the
  intended app language and waiting for any UI/model language update before
  asserting translated output;
- document any required GitHub Environment protections and repository secrets
  without committing secret values;
- run `git diff --check` for docs-only hygiene changes, plus the relevant build
  or test command when behavior, tooling, signing, or workflow execution
  changes.

## Emergency Skip

`DJCONNECT_SKIP_THIRDPARTY_UPDATE=1` may be used only when the package registry or local toolchain is unavailable. Add a follow-up issue before publishing a production release.
