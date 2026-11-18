#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.xcode-derived-ios-matrix"
SCHEME="DJConnectIOS"
CONFIGURATION="Debug"
MIN_IOS_MAJOR=26
INCLUDE_BETA_RUNTIMES=0
ALL_RUNTIMES=0
FULL_UI=0
LIST_ONLY=0
KEEP_DEVICES=0
FRESH_BOOT=1
RETRIES=1
MONKEY_SECONDS="${DJCONNECT_MONKEY_SECONDS:-12}"
TEST_SELECTOR="DJConnectIOSUITests/DJConnectIOSUITests/testMonkeyModeSafeNavigationSmoke"

usage() {
  cat <<'USAGE'
Usage:
  Tools/test_ios_simulator_matrix.sh [options]

Options:
  --full-ui                Run the full DJConnectIOSUITests target instead of the short monkey smoke.
  --all-runtimes           Run every installed iOS runtime >= iOS 26 for every form factor.
  --include-beta-runtimes  Include simulator runtimes whose build number looks like a beta/pre-release.
  --monkey-seconds N       Duration for the monkey smoke test. Default: 12.
  --retries N              Retry a failed simulator row N times. Default: 1.
  --no-fresh-boot          Do not erase and boot each temporary simulator before testing.
  --keep-devices           Keep temporary simulators after the run for manual inspection.
  --list                   Print the resolved matrix without running tests.
  -h, --help               Show this help.

The default matrix runs:
  - compact iPhone on the latest installed stable iOS runtime
  - standard iPhone on the oldest and latest installed stable iOS runtime
  - large iPhone on the latest installed stable iOS runtime
  - iPad on the latest installed stable iOS runtime

Install older simulator runtimes in Xcode when you want local coverage closer to
the app deployment target. The app currently supports iOS/iPadOS 26.0 and newer.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full-ui)
      FULL_UI=1
      shift
      ;;
    --all-runtimes)
      ALL_RUNTIMES=1
      shift
      ;;
    --include-beta-runtimes)
      INCLUDE_BETA_RUNTIMES=1
      shift
      ;;
    --monkey-seconds)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]]; then
        echo "--monkey-seconds requires a positive number." >&2
        exit 64
      fi
      MONKEY_SECONDS="$2"
      shift 2
      ;;
    --keep-devices)
      KEEP_DEVICES=1
      shift
      ;;
    --no-fresh-boot)
      FRESH_BOOT=0
      shift
      ;;
    --retries)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "--retries requires a non-negative number." >&2
        exit 64
      fi
      RETRIES="$2"
      shift 2
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required." >&2
  exit 1
fi

if ! xcrun simctl list runtimes >/dev/null 2>&1; then
  echo "xcrun simctl is required and must be able to read simulator runtimes." >&2
  exit 1
fi

declare -a CREATED_DEVICES=()

cleanup() {
  if [[ "$KEEP_DEVICES" -eq 1 ]]; then
    return
  fi
  for udid in "${CREATED_DEVICES[@]:-}"; do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

device_type_id_for_name() {
  local wanted="$1"
  local line
  while IFS= read -r line; do
    if [[ "$line" == "$wanted ("* ]]; then
      printf '%s\n' "$line" | sed -E 's/^.*\(([^()]*)\)$/\1/'
      return 0
    fi
  done < <(xcrun simctl list devicetypes)
  return 1
}

first_available_device_type() {
  local candidate
  for candidate in "$@"; do
    if device_type_id_for_name "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

installed_ios_runtimes() {
  local line version build runtime_id major
  while IFS= read -r line; do
    [[ "$line" == iOS\ * ]] || continue
    [[ "$line" == *"(unavailable"* ]] && continue
    version="$(printf '%s\n' "$line" | sed -E 's/^iOS ([0-9.]+) .*$/\1/')"
    build="$(printf '%s\n' "$line" | sed -E 's/^iOS [0-9.]+ \([0-9.]+ - ([^)]*)\).*$/\1/')"
    runtime_id="$(printf '%s\n' "$line" | sed -E 's/^.* - (com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+)$/\1/')"
    major="${version%%.*}"
    [[ "$major" =~ ^[0-9]+$ ]] || continue
    [[ "$major" -ge "$MIN_IOS_MAJOR" ]] || continue
    if [[ "$INCLUDE_BETA_RUNTIMES" -eq 0 && "$build" =~ [a-z]$ ]]; then
      continue
    fi
    printf '%s|%s\n' "$version" "$runtime_id"
  done < <(xcrun simctl list runtimes)
}

unique_runtime_versions() {
  installed_ios_runtimes | sort -t '|' -k1,1V
}

latest_runtime() {
  unique_runtime_versions | tail -n 1
}

oldest_runtime() {
  unique_runtime_versions | head -n 1
}

runtime_version() {
  printf '%s\n' "$1" | cut -d '|' -f 1
}

runtime_id() {
  printf '%s\n' "$1" | cut -d '|' -f 2
}

add_row() {
  local label="$1"
  local device_name="$2"
  local runtime="$3"
  [[ -n "$device_name" && -n "$runtime" ]] || return 0
  MATRIX_LABELS+=("$label")
  MATRIX_DEVICES+=("$device_name")
  MATRIX_RUNTIME_VERSIONS+=("$(runtime_version "$runtime")")
  MATRIX_RUNTIME_IDS+=("$(runtime_id "$runtime")")
}

declare -a MATRIX_LABELS=()
declare -a MATRIX_DEVICES=()
declare -a MATRIX_RUNTIME_VERSIONS=()
declare -a MATRIX_RUNTIME_IDS=()

compact_iphone="$(first_available_device_type \
  "iPhone SE (3rd generation)" \
  "iPhone 13 mini" \
  "iPhone 12 mini" \
  "iPhone SE (2nd generation)" \
  || true)"
standard_iphone="$(first_available_device_type \
  "iPhone 17" \
  "iPhone 17 Pro" \
  "iPhone 16" \
  "iPhone 15" \
  "iPhone 14" \
  || true)"
large_iphone="$(first_available_device_type \
  "iPhone 17 Pro Max" \
  "iPhone 16 Pro Max" \
  "iPhone 15 Pro Max" \
  "iPhone 14 Pro Max" \
  || true)"
ipad="$(first_available_device_type \
  "iPad (A16)" \
  "iPad Pro 11-inch (M4)" \
  "iPad Air 11-inch (M4)" \
  "iPad (10th generation)" \
  "iPad Pro 12.9-inch (6th generation)" \
  || true)"

latest="$(latest_runtime || true)"
oldest="$(oldest_runtime || true)"

if [[ -z "$latest" ]]; then
  echo "No stable iOS simulator runtime >= iOS $MIN_IOS_MAJOR found." >&2
  echo "Install an iOS simulator runtime in Xcode, or rerun with --include-beta-runtimes." >&2
  exit 1
fi

if [[ "$ALL_RUNTIMES" -eq 1 ]]; then
  while IFS= read -r runtime; do
    add_row "compact-phone" "$compact_iphone" "$runtime"
    add_row "standard-phone" "$standard_iphone" "$runtime"
    add_row "large-phone" "$large_iphone" "$runtime"
    add_row "ipad" "$ipad" "$runtime"
  done < <(unique_runtime_versions)
else
  add_row "compact-phone" "$compact_iphone" "$latest"
  add_row "standard-phone-oldest-runtime" "$standard_iphone" "$oldest"
  if [[ "$(runtime_version "$oldest")" != "$(runtime_version "$latest")" ]]; then
    add_row "standard-phone-latest-runtime" "$standard_iphone" "$latest"
  fi
  add_row "large-phone" "$large_iphone" "$latest"
  add_row "ipad" "$ipad" "$latest"
fi

if [[ "${#MATRIX_LABELS[@]}" -eq 0 ]]; then
  echo "No runnable iOS simulator matrix rows could be resolved." >&2
  exit 1
fi

echo "DJConnect iOS simulator matrix:"
for index in "${!MATRIX_LABELS[@]}"; do
  printf '  %-31s iOS %-7s %s\n' \
    "${MATRIX_LABELS[$index]}" \
    "${MATRIX_RUNTIME_VERSIONS[$index]}" \
    "${MATRIX_DEVICES[$index]}"
done

if [[ "$LIST_ONLY" -eq 1 ]]; then
  exit 0
fi

rm -rf "$DERIVED_DATA"
mkdir -p "$DERIVED_DATA"

run_xcodebuild_row() {
  local label="$1"
  local runtime_version="$2"
  local udid="$3"
  local attempt="$4"
  local log_file="$DERIVED_DATA/$label-$runtime_version-attempt-$attempt.log"

  args=(
    xcodebuild
    -quiet
    -project "$ROOT_DIR/DJConnectApp.xcodeproj"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "platform=iOS Simulator,id=$udid"
    -derivedDataPath "$DERIVED_DATA/$label-$runtime_version"
    CODE_SIGNING_ALLOWED=NO
  )
  if [[ "$FULL_UI" -eq 0 ]]; then
    args+=(-only-testing:"$TEST_SELECTOR")
  fi

  echo "  attempt $attempt log: $log_file"
  if DJCONNECT_MONKEY_SECONDS="$MONKEY_SECONDS" "${args[@]}" test >"$log_file" 2>&1; then
    return 0
  fi

  echo "  attempt $attempt failed. Last log lines:"
  tail -n 40 "$log_file" || true
  return 1
}

for index in "${!MATRIX_LABELS[@]}"; do
  label="${MATRIX_LABELS[$index]}"
  device_name="${MATRIX_DEVICES[$index]}"
  runtime_version="${MATRIX_RUNTIME_VERSIONS[$index]}"
  runtime_id="${MATRIX_RUNTIME_IDS[$index]}"
  device_type_id="$(device_type_id_for_name "$device_name")"
  simulator_name="DJConnect Matrix ${label} iOS ${runtime_version} $$"
  udid="$(xcrun simctl create "$simulator_name" "$device_type_id" "$runtime_id")"
  CREATED_DEVICES+=("$udid")

  echo
  echo "Running $label on $device_name / iOS $runtime_version ($udid)"

  if [[ "$FRESH_BOOT" -eq 1 ]]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid" >/dev/null
    xcrun simctl boot "$udid" >/dev/null
    xcrun simctl bootstatus "$udid" -b >/dev/null
  fi

  attempt=0
  until run_xcodebuild_row "$label" "$runtime_version" "$udid" "$attempt"; do
    if [[ "$attempt" -ge "$RETRIES" ]]; then
      echo "Row failed after $((attempt + 1)) attempt(s): $label / iOS $runtime_version" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    echo "  retrying after simulator shutdown/boot..."
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl boot "$udid" >/dev/null
    xcrun simctl bootstatus "$udid" -b >/dev/null
  done
done

echo
echo "iOS simulator matrix completed."
