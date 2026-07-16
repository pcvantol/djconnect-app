# macOS CI Tooling Maintenance

- **Prompt ID:** `APPLE-RUNNER-CI-TOOLING-MAINTENANCE-001`
- **Title:** Keep macOS runner CI tooling current
- **Generation:** 2
- **Engineering program:** Platform Release Engineering
- **Branch:** `codex/automate-macos-ci-tooling-maintenance`
- **Commit SHA:** `d12ad0f981848d13dab3b04dffa4a8bfb0b5777e`
- **Pull request:** reviewable pull request created from this branch
- **Decision:** `MACOS_CI_TOOLING_MAINTENANCE_REVIEWABLE`

## Validation summary

The previous Apple build-engineering PR #27 is merged. The new maintenance
scripts pass `bash -n`. The installer statically verifies the launchd plist,
registers the task in the runner user's GUI domain and can wait for the first
maintenance result. The maintenance task updates only already-installed
Homebrew CI formulae and records tool versions. It does not modify Xcode.

## Created artifacts

- `scripts/runner/macos-ci-tooling-maintenance.sh`
- `scripts/runner/install_macos_ci_tooling_maintenance.sh`
- `docs/MACOS_RUNNER_CI_TOOLING_MAINTENANCE.md`
- This immutable Prompt History record.

## Updated artifacts

- Rolling engineering, repository, management and prompt records.

## Known limitations

- The runner user must install the LaunchAgent once after merge.
- Homebrew requires network access and upgrades only already-installed helper
  formulae.
- Xcode remains an explicitly qualified Apple toolchain update, not an
  unattended CI-tooling update.

## Deferred work

- Install and verify the maintenance task on the macOS runner.
- Continue release deployment work only through its separately authorized
  target flows.

## Recommended next prompt

No new engineering increment is selected. Verify the installed maintenance
task operationally, then return to the explicitly authorized release target.
