#!/usr/bin/env bash
set -euo pipefail

PUBLIC_REPO="${PUBLIC_REPO:-pcvantol/djconnect-app-releases}"
SCHEME="${SCHEME:-DJConnectMac}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-.release/DJConnect.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-.release/export}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-.release/artifacts}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.release/DerivedData}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-Tools/release/ExportOptions-macOS.plist}"

usage() {
  cat <<EOF
Usage:
  PUBLIC_REPO=pcvantol/djconnect-app-releases \\
  DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \\
  NOTARY_PROFILE=<xcrun-notarytool-keychain-profile> \\
  ./Tools/release/release_macos_public.sh [--version X.Y.Z] [--skip-upload]

Environment:
  PUBLIC_REPO              Public GitHub repo for binary releases.
                           Default: pcvantol/djconnect-app-releases
  DEVELOPMENT_TEAM         Apple Developer Team ID for signing.
  NOTARY_PROFILE           Keychain profile created with xcrun notarytool
                           store-credentials.
  EXPORT_OPTIONS_PLIST     Export options plist. Default:
                           Tools/release/ExportOptions-macOS.plist

This script archives, exports, notarizes, staples, zips, checksums, and uploads
a public macOS binary release. It intentionally does not build iOS; iOS public
distribution should go through TestFlight/App Store.
EOF
}

VERSION=""
SKIP_UPLOAD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "--version requires a value." >&2
        exit 64
      fi
      VERSION="$2"
      shift 2
      ;;
    --skip-upload)
      SKIP_UPLOAD=true
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command git
require_command xcodebuild
require_command xcrun
require_command ditto
require_command shasum

if [[ "$SKIP_UPLOAD" == false ]]; then
  require_command gh
fi

if [[ ! -d ".git" || ! -d "DJConnectApp.xcodeproj" ]]; then
  echo "Run this script from the djconnect-app repository root." >&2
  exit 1
fi

if [[ "${DJCONNECT_SKIP_THIRDPARTY_UPDATE:-0}" != "1" && "${DJCONNECT_THIRDPARTY_PREFLIGHT_DONE:-0}" != "1" ]]; then
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update_thirdparty.sh"
  export DJCONNECT_THIRDPARTY_PREFLIGHT_DONE=1
elif [[ "${DJCONNECT_SKIP_THIRDPARTY_UPDATE:-0}" == "1" ]]; then
  echo "Skipping third-party update preflight (DJCONNECT_SKIP_THIRDPARTY_UPDATE=1)."
fi

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "Set DEVELOPMENT_TEAM to your Apple Developer Team ID." >&2
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Set NOTARY_PROFILE to an xcrun notarytool keychain profile." >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :settings:base:MARKETING_VERSION' project.yml 2>/dev/null || true)"
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(grep -E 'MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
fi

if [[ -z "$VERSION" ]]; then
  echo "Could not determine version. Pass --version X.Y.Z." >&2
  exit 1
fi

TAG="v${VERSION}"
APP_NAME="DJConnect"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
ZIP_NAME="DJConnect-macOS-${VERSION}.zip"
ZIP_PATH="${ARTIFACTS_PATH}/${ZIP_NAME}"
CHECKSUM_PATH="${ZIP_PATH}.sha256"
NOTARY_ZIP_PATH="${ARTIFACTS_PATH}/DJConnect-macOS-${VERSION}-notary.zip"
RESOLVED_EXPORT_OPTIONS_PLIST=".release/ExportOptions-macOS.resolved.plist"

if [[ "$SKIP_UPLOAD" == false ]] && ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run gh auth login first." >&2
  exit 1
fi

echo "Preparing macOS release ${TAG}"
echo "Public repo: ${PUBLIC_REPO}"

rm -rf .release
mkdir -p "$EXPORT_PATH" "$ARTIFACTS_PATH"
sed "s/__DEVELOPMENT_TEAM__/${DEVELOPMENT_TEAM}/g" \
  "$EXPORT_OPTIONS_PLIST" > "$RESOLVED_EXPORT_OPTIONS_PLIST"

xcodebuild \
  -project DJConnectApp.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean

xcodebuild \
  -project DJConnectApp.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$RESOLVED_EXPORT_OPTIONS_PLIST"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Export did not produce ${APP_PATH}." >&2
  exit 1
fi

ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"

xcrun notarytool submit "$NOTARY_ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Created:"
echo "  $ZIP_PATH"
echo "  $CHECKSUM_PATH"

if [[ "$SKIP_UPLOAD" == true ]]; then
  echo "Skipping upload."
  exit 0
fi

if ! gh release view "$TAG" --repo "$PUBLIC_REPO" >/dev/null 2>&1; then
  gh release create "$TAG" \
    --repo "$PUBLIC_REPO" \
    --title "DJConnect macOS ${VERSION}" \
    --notes "Public macOS binary release for DJConnect ${VERSION}."
fi

gh release upload "$TAG" "$ZIP_PATH" "$CHECKSUM_PATH" \
  --repo "$PUBLIC_REPO" \
  --clobber

echo "Uploaded to https://github.com/${PUBLIC_REPO}/releases/tag/${TAG}"
