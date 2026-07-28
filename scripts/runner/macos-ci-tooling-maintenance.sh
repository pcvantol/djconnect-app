#!/bin/bash
set -euo pipefail

readonly SUPPORT_DIR="$HOME/Library/Application Support/DJConnect/runner-maintenance"
readonly LOG_DIR="$HOME/Library/Logs/DJConnect"
readonly LOG_FILE="$LOG_DIR/ci-tooling-maintenance.log"
readonly STATUS_FILE="$LOG_DIR/ci-tooling-maintenance.status"
readonly LOCK_DIR="$SUPPORT_DIR/ci-tooling-maintenance.lock"
readonly RUNNER_ROOT="${DJCONNECT_RUNNER_ROOT:-$HOME/actions-runners}"
readonly RUNNER_WORKSPACE_RETENTION_DAYS="${DJCONNECT_RUNNER_WORKSPACE_RETENTION_DAYS:-1}"
readonly RUNNER_DIAGNOSTIC_RETENTION_DAYS="${DJCONNECT_RUNNER_DIAGNOSTIC_RETENTION_DAYS:-14}"

mkdir -p "$SUPPORT_DIR" "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

require_positive_integer() {
  local value="$1" name="$2"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s %s must be a positive integer.\n' "$(timestamp)" "$name"
    exit 2
  fi
}

write_status() {
  printf '%s %s\n' "$(timestamp)" "$1" >"$STATUS_FILE"
}

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

on_error() {
  write_status "FAILED at line $1"
  cleanup
}

trap 'on_error $LINENO' ERR
trap cleanup EXIT

require_positive_integer "$RUNNER_WORKSPACE_RETENTION_DAYS" 'DJCONNECT_RUNNER_WORKSPACE_RETENTION_DAYS'
require_positive_integer "$RUNNER_DIAGNOSTIC_RETENTION_DAYS" 'DJCONNECT_RUNNER_DIAGNOSTIC_RETENTION_DAYS'

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf '%s CI tooling maintenance already running; skipping duplicate launch.\n' "$(timestamp)"
  exit 0
fi

write_status 'RUNNING'
printf '%s Starting macOS CI tooling maintenance.\n' "$(timestamp)"

runner_has_active_worker() {
  local runner_dir="$1"
  pgrep -f "$runner_dir/bin/Runner.Worker" >/dev/null 2>&1
}

workspace_has_recent_activity() {
  local workspace="$1"
  find "$workspace" -type f -mtime "-$RUNNER_WORKSPACE_RETENTION_DAYS" -print -quit | grep -q .
}

cleanup_runner_workspaces() {
  local runner_dir runner_name workspace git_dir repository before_kb after_kb
  local removed_workspaces=0 skipped_active=0 skipped_recent=0 cleaned_diagnostics=0

  [[ -d "$RUNNER_ROOT" ]] || {
    printf '%s No local GitHub Actions runner root at %s; skipping workspace cleanup.\n' "$(timestamp)" "$RUNNER_ROOT"
    return
  }

  printf '%s Checking temporary GitHub Actions runner workspaces under %s.\n' "$(timestamp)" "$RUNNER_ROOT"
  for runner_dir in "$RUNNER_ROOT"/*; do
    [[ -d "$runner_dir" && -f "$runner_dir/.runner" && -d "$runner_dir/_work" ]] || continue
    runner_name="$(basename "$runner_dir")"

    if runner_has_active_worker "$runner_dir"; then
      skipped_active=$((skipped_active + 1))
      printf '%s Skipping active runner %s.\n' "$(timestamp)" "$runner_name"
      continue
    fi

    while IFS= read -r -d '' git_dir; do
      repository="${git_dir%/.git}"
      if workspace_has_recent_activity "$repository"; then
        skipped_recent=$((skipped_recent + 1))
        printf '%s Preserving recently active workspace %s.\n' "$(timestamp)" "$repository"
        continue
      fi

      before_kb="$(du -sk "$repository" | awk '{print $1}')"
      git -C "$repository" clean -ffdX
      after_kb="$(du -sk "$repository" | awk '{print $1}')"
      removed_workspaces=$((removed_workspaces + 1))
      printf '%s Cleaned ignored build output in %s (%sKB -> %sKB).\n' "$(timestamp)" "$repository" "$before_kb" "$after_kb"
    done < <(find "$runner_dir/_work" -mindepth 2 -maxdepth 6 -type d -name .git -print0)

    if [[ -d "$runner_dir/_diag" ]]; then
      while IFS= read -r -d '' diagnostic; do
        rm -f -- "$diagnostic"
        cleaned_diagnostics=$((cleaned_diagnostics + 1))
      done < <(find "$runner_dir/_diag" -type f -mtime "+$RUNNER_DIAGNOSTIC_RETENTION_DAYS" -print0)
    fi
  done

  printf '%s Runner workspace cleanup complete: %s cleaned, %s active runner(s) skipped, %s recently active workspace(s) preserved, %s expired diagnostic log(s) removed.\n' \
    "$(timestamp)" "$removed_workspaces" "$skipped_active" "$skipped_recent" "$cleaned_diagnostics"
}

cleanup_runner_workspaces

if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    printf '%s Homebrew is unavailable.\n' "$(timestamp)"
    exit 1
  fi
fi

brew update

# This is the designated tooling-currency owner for the macOS runner host.
# Formulae are safe to update as the runner user. Casks are upgraded one at a
# time so a package which requires an interactive macOS administrator prompt
# does not prevent the remaining non-privileged maintenance from succeeding.
# No ngrok tunnel/auth-token configuration is read or changed here.
printf '%s Upgrading all installed Homebrew formulae.\n' "$(timestamp)"
brew upgrade --formula

manual_admin_casks=()
outdated_casks="$(brew outdated --cask --quiet)"
if [[ -n "$outdated_casks" ]]; then
  printf '%s Upgrading all installed Homebrew casks.\n' "$(timestamp)"
  while IFS= read -r cask; do
    [[ -n "$cask" ]] || continue
    printf '%s Upgrading Homebrew cask: %s\n' "$(timestamp)" "$cask"
    set +e
    cask_output="$(brew upgrade --cask "$cask" 2>&1)"
    cask_status=$?
    set -e
    [[ -n "$cask_output" ]] && printf '%s\n' "$cask_output"
    if [[ "$cask_status" -eq 0 ]]; then
      continue
    fi
    if grep -Eqi 'sudo: a terminal is required|sudo: a password is required' <<<"$cask_output"; then
      manual_admin_casks+=("$cask")
      printf '%s ADMIN MAINTENANCE REQUIRED: Homebrew cask %s requires an interactive administrator update.\n' "$(timestamp)" "$cask"
      continue
    fi
    printf '%s FAILED: Homebrew cask %s upgrade exited with %s.\n' "$(timestamp)" "$cask" "$cask_status"
    exit "$cask_status"
  done <<<"$outdated_casks"
else
  printf '%s All Homebrew casks are current.\n' "$(timestamp)"
fi

# Tailscale's signed macOS application has its own update channel. Keep that
# explicit preference enabled; this task deliberately does not replace an
# independently installed app with a Homebrew cask.
if command -v tailscale >/dev/null 2>&1; then
  if tailscale set --auto-update; then
    printf '%s Tailscale signed-app auto-update is enabled.\n' "$(timestamp)"
  else
    printf '%s WARNING: Tailscale auto-update could not be enabled; rerun DJConnect onboarding repair to restore the declared setting.\n' "$(timestamp)"
  fi
else
  printf '%s Tailscale CLI is unavailable; leaving it absent.\n' "$(timestamp)"
fi

for command in xcodebuild swift git gh xcodegen node python3; do
  if command -v "$command" >/dev/null 2>&1; then
    printf '%s %s: %s\n' "$(timestamp)" "$command" "$("$command" --version 2>&1 | head -n 1)"
  else
    printf '%s MISSING: %s\n' "$(timestamp)" "$command"
  fi
done

if (( ${#manual_admin_casks[@]} > 0 )); then
  write_status "SUCCESS (ADMIN MAINTENANCE REQUIRED: ${manual_admin_casks[*]})"
else
  write_status 'SUCCESS'
fi
printf '%s macOS CI tooling maintenance completed.\n' "$(timestamp)"
