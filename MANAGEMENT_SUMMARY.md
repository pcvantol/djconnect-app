# DJConnect App Management Summary

Status: macOS runner CI-tooling maintenance increment reviewable

## Decision

Keep the macOS self-hosted runner's installed Homebrew CI tooling current
without changing the Apple project architecture or toolchain-selection policy.

## Scope and Outcome

PR #27 is merged. The current reviewable increment adds a daily user-level
launchd task that updates only already-installed Homebrew CI helper tools,
captures tool versions and verifies its first execution. Xcode is deliberately
not updated unattended because its version controls signing, SDK and simulator
qualification.

## Known Limitation

An administrator is not needed, but the same logged-in user that owns the
Apple GitHub Actions runner must install the LaunchAgent once after merge.

## Recommended Next Prompt

Install and verify the maintenance task after merge. No further engineering
increment is selected automatically.
