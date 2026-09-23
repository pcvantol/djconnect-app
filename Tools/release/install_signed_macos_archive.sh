#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: install_signed_macos_archive.sh ARCHIVE SHA256 VERSION HOST_UUID RUN_ID" >&2
  exit 2
fi

archive=$1
expected_sha=$2
expected_version=$3
expected_uuid=$4
run_id=$5

[[ -f "$archive" ]] || { echo "signed archive missing" >&2; exit 1; }
[[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || exit 2
[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
[[ "$expected_uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || exit 2
[[ "$run_id" =~ ^[0-9]+$ ]] || exit 2

observed_uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4; exit}')
[[ "$observed_uuid" == "$expected_uuid" ]] || { echo "unexpected deployment host" >&2; exit 1; }
observed_sha=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ "$observed_sha" == "$expected_sha" ]] || { echo "signed archive checksum mismatch" >&2; exit 1; }

staging=$(mktemp -d)
trap 'rm -rf -- "$staging"' EXIT
ditto -x -k "$archive" "$staging"
app_bundle="$staging/DJConnect.app"
[[ -d "$app_bundle" && ! -L "$app_bundle" ]] || { echo "DJConnect.app missing from signed archive" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_bundle/Contents/Info.plist")" == dev.djconnect.mac ]] || exit 1
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")" == "$expected_version" ]] || exit 1
codesign --verify --deep --strict "$app_bundle"

install_root="$HOME/Applications"
install_path="$install_root/DJConnect.app"
replacement_path="$install_root/.DJConnect-${run_id}.app"
recovery_path="$install_root/.DJConnect-pre-${run_id}.app"
[[ ! -L "$install_root" && ! -L "$install_path" ]] || { echo "unsafe installation path" >&2; exit 1; }
mkdir -p "$install_root"
[[ ! -e "$replacement_path" && ! -L "$replacement_path" ]] || exit 1
[[ ! -e "$recovery_path" && ! -L "$recovery_path" ]] || exit 1
ditto "$app_bundle" "$replacement_path"
codesign --verify --deep --strict "$replacement_path"
if [[ -e "$install_path" ]]; then
  mv "$install_path" "$recovery_path"
fi
if ! mv "$replacement_path" "$install_path"; then
  if [[ -e "$recovery_path" && ! -e "$install_path" ]]; then
    mv "$recovery_path" "$install_path"
  fi
  echo "installation failed; previous app restored when available" >&2
  exit 1
fi
codesign --verify --deep --strict "$install_path"
