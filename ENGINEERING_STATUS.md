# DJConnect App Engineering Status

Status: macOS runner CI-tooling maintenance increment reviewable

Repository: `pcvantol/djconnect-app`

## Current Engineering State

Apple Release Version Integrity and the subsequent unsigned iOS Simulator
build qualification are merged into `main`; PR #27 merged as
`b04bf915c711a3a669e5a4bd43a140325f30deb9`. The active bounded increment adds
launchd-based maintenance for the Apple self-hosted runner's Homebrew CI
tooling. It does not change Xcode, signing, source code, release artifacts or
deployment authorization.

## Qualification Context

- The predecessor PR #27 is objectively merged and no Apple repository PR is
  open.
- The maintenance scripts pass `bash -n` and their launchd schedule, version
  logging and bounded Homebrew formula allowlist are statically verified.

## Current Decision

The maintenance task runs as the runner's logged-in user, updates only
installed CI helper formulae daily, records tool versions and requires an
explicit first-run verification. Xcode is intentionally recorded but not
updated unattended because Apple toolchain changes require qualification.

Decision: `MACOS_CI_TOOLING_MAINTENANCE_REVIEWABLE`. Stop after the reviewable
pull request; do not begin a subsequent increment automatically.

## Planning Entry Point

Read `ROADMAP_INDEX.md`, then `PROMPT_INDEX.md`.
