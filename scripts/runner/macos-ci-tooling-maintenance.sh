#!/bin/bash
set -euo pipefail

readonly SUPPORT_DIR="$HOME/Library/Application Support/DJConnect/runner-maintenance"
readonly LOG_DIR="$HOME/Library/Logs/DJConnect"
readonly LOG_FILE="$LOG_DIR/ci-tooling-maintenance.log"
readonly STATUS_FILE="$LOG_DIR/ci-tooling-maintenance.status"
readonly LOCK_DIR="$SUPPORT_DIR/ci-tooling-maintenance.lock"

mkdir -p "$SUPPORT_DIR" "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
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

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf '%s CI tooling maintenance already running; skipping duplicate launch.\n' "$(timestamp)"
  exit 0
fi

write_status 'RUNNING'
printf '%s Starting macOS CI tooling maintenance.\n' "$(timestamp)"

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
