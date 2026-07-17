#!/bin/bash
set -euo pipefail

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo 'This installer runs only on macOS.' >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  echo 'Run this as the logged-in Apple runner user, not with sudo.' >&2
  exit 1
fi

run_now=false
if [[ "${1:-}" == '--run-now' ]]; then
  run_now=true
elif [[ "$#" -ne 0 ]]; then
  echo 'Usage: install_macos_ci_tooling_maintenance.sh [--run-now]' >&2
  exit 1
fi

readonly LABEL='com.djconnect.ci-tooling-maintenance'
readonly UID_VALUE="$(id -u)"
readonly DOMAIN="gui/$UID_VALUE"
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SUPPORT_DIR="$HOME/Library/Application Support/DJConnect/runner-maintenance"
readonly LOG_DIR="$HOME/Library/Logs/DJConnect"
readonly PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
readonly INSTALLED_SCRIPT="$SUPPORT_DIR/macos-ci-tooling-maintenance.sh"
readonly STATUS_FILE="$LOG_DIR/ci-tooling-maintenance.status"

mkdir -p "$SUPPORT_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"
install -m 0755 "$SOURCE_DIR/macos-ci-tooling-maintenance.sh" "$INSTALLED_SCRIPT"

cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$INSTALLED_SCRIPT</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>10</integer>
  <key>Minute</key>
  <integer>0</integer>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>ProcessType</key>
  <string>Background</string>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/ci-tooling-maintenance.launchd.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/ci-tooling-maintenance.launchd.error.log</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST"
launchctl bootout "$DOMAIN" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST"

if [[ "$run_now" == true ]]; then
  start_epoch="$(date +%s)"
  launchctl kickstart -k "$DOMAIN/$LABEL"
  deadline=$((start_epoch + 1800))
  while (( $(date +%s) < deadline )); do
    if [[ -f "$STATUS_FILE" ]] && [[ "$(stat -f %m "$STATUS_FILE")" -ge "$start_epoch" ]]; then
      if grep -q ' SUCCESS$' "$STATUS_FILE"; then
        cat "$STATUS_FILE"
        exit 0
      fi
      if grep -q ' FAILED ' "$STATUS_FILE"; then
        cat "$STATUS_FILE" >&2
        exit 1
      fi
    fi
    sleep 2
  done
  echo "Timed out waiting for $LABEL. Inspect $LOG_DIR/ci-tooling-maintenance.log" >&2
  exit 1
fi

launchctl print "$DOMAIN/$LABEL" | sed -n '1,20p'
echo "Installed $LABEL. Run again with --run-now to verify the first maintenance execution."
