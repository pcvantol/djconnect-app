# macOS Runner Workspace Retention

- **Prompt ID:** `APPLE-RUNNER-WORKSPACE-RETENTION-001`
- **Title:** Bound persistent self-hosted runner workspace storage
- **Generation:** 2
- **Engineering program:** Platform Release Engineering
- **Branch:** `codex/add-runner-workspace-cleanup`
- **Pull request:** reviewable pull request created from this branch
- **Decision:** `MACOS_RUNNER_WORKSPACE_RETENTION_REVIEWABLE`

## Objective

Extend the existing daily macOS CI-tooling maintenance task with safe cleanup
of temporary self-hosted runner workspaces. The task must preserve formal
qualification and release evidence while reclaiming Git-ignored build output
from inactive worktrees and expired runner diagnostics.

## Scope and boundaries

- Cleans only Git-ignored files in a Git worktree below the dedicated
  `~/actions-runners` root.
- Skips any runner with an active `Runner.Worker` process and preserves
  worktrees with file activity during the configured retention window.
- Removes only runner diagnostic logs older than fourteen days by default.
- Does not alter runner binaries, update state, Actions caches, source,
  published artifacts, release assets or durable qualification/release
  evidence.

## Validation summary

- `bash -n scripts/runner/macos-ci-tooling-maintenance.sh` passed.
- An isolated runner fixture confirmed that old Git-ignored build output and
  expired diagnostics are removed while a non-ignored local file is retained.
- `git diff --check` passed.

## Updated artifacts

- `scripts/runner/macos-ci-tooling-maintenance.sh`
- `docs/MACOS_RUNNER_CI_TOOLING_MAINTENANCE.md`
- This immutable Prompt History record.
