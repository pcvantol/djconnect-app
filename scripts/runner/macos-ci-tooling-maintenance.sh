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
# Upgrade every already-installed Homebrew formula and cask, rather than a
# brittle allowlist. `brew upgrade` never installs a missing package, and no
# ngrok tunnel/auth-token configuration is read or changed here.
printf '%s Upgrading all installed Homebrew formulae.\n' "$(timestamp)"
brew upgrade
printf '%s Upgrading all installed Homebrew casks.\n' "$(timestamp)"
brew upgrade --cask

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

write_status 'SUCCESS'
printf '%s macOS CI tooling maintenance completed.\n' "$(timestamp)"
