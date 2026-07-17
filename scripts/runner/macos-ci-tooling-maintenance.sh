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

# Match the repository's release-hygiene tool set and upgrade only tools already
# installed as Homebrew formulae. Xcode is recorded below but never changed by
# this unattended task: its version must remain an explicit runner qualification.
for formula in gh xcodegen swiftlint xcbeautify create-dmg mas node; do
  if brew list --formula "$formula" >/dev/null 2>&1; then
    printf '%s Upgrading Homebrew formula: %s\n' "$(timestamp)" "$formula"
    brew upgrade "$formula"
  else
    printf '%s Formula not installed; leaving it absent: %s\n' "$(timestamp)" "$formula"
  fi
done

# ngrok is a Homebrew-managed development-network dependency. Upgrade it only
# when it is already installed: the maintenance task must not create a tunnel,
# request an auth token or change a developer's local ngrok configuration.
if brew list --cask ngrok >/dev/null 2>&1; then
  printf '%s Upgrading Homebrew cask: ngrok\n' "$(timestamp)"
  brew upgrade --cask ngrok
else
  printf '%s ngrok cask is not installed; leaving it absent.\n' "$(timestamp)"
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

write_status 'SUCCESS'
printf '%s macOS CI tooling maintenance completed.\n' "$(timestamp)"
