#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-$HOME/Library/Developer/Xcode/DerivedData/DJConnectApp-eufxsiyhcinxcmbanidfajglnhev/Build/Products/Debug-watchsimulator/DJConnect.app}"
BUNDLE_ID="${BUNDLE_ID:-dev.djconnect.ios.watch}"
LANGUAGE_ARGS=(-AppleLanguages "(nl)" -AppleLocale nl_NL)

SCREENS=(
  "01-now-playing:now-playing"
  "02-output:outputs"
  "03-queue:queue"
  "04-ask-dj:ask-dj"
  "05-track-insight:track-insight"
  "06-music-dna:music-dna"
  "07-playlists:playlists"
  "08-settings:settings"
  "09-logs:logs"
  "10-about:about"
  "11-legal:legal"
  "12-privacy:privacy"
  "13-feedback:feedback"
)

DEVICES=(
  "2281E44A-3F5E-40F9-BEDE-57A31AF4B553:screenshots/apple-watch-se-3-40mm-watchos-26-5-324x394"
  "0C53A26B-DD57-4AFC-9335-FE4753915B9D:screenshots/apple-watch-ultra-3-49mm-watchos-27-0-410x502"
)

usage() {
  cat <<USAGE
Usage: $0 [--device UDID:output-dir]...

Build DJConnectWatch first, then captures every demo Watch screen into the
configured screenshot folders. Override APP_PATH and BUNDLE_ID via env vars.
USAGE
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  DEVICES=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device)
        DEVICES+=("$2")
        shift 2
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Watch app not found: $APP_PATH" >&2
  echo "Run: xcodebuild build -scheme DJConnectWatch -destination 'generic/platform=watchOS Simulator'" >&2
  exit 1
fi

for device in "${DEVICES[@]}"; do
  udid="${device%%:*}"
  output_dir="${device#*:}"
  mkdir -p "$output_dir"
  find "$output_dir" -maxdepth 1 -type f -name '*.png' -delete

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$APP_PATH"

  for entry in "${SCREENS[@]}"; do
    file_prefix="${entry%%:*}"
    screen="${entry#*:}"
    output_path="$output_dir/$file_prefix.png"

    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
      --monkey-testing "--screenshot-screen=$screen" "${LANGUAGE_ARGS[@]}" >/dev/null
    sleep 2
    xcrun simctl io "$udid" screenshot "$output_path" >/dev/null
    echo "$output_path"
  done
done
