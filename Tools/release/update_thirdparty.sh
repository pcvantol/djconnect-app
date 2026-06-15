#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$ROOT_DIR/build/release"
REPORT_FILE="$REPORT_DIR/thirdparty-update-report.txt"

mkdir -p "$REPORT_DIR"
: > "$REPORT_FILE"

log() {
  printf '%s\n' "$*" | tee -a "$REPORT_FILE"
}

package_resolved_snapshot() {
  find "$ROOT_DIR" \
    -path "$ROOT_DIR/.git" -prune -o \
    -path "$ROOT_DIR/.build" -prune -o \
    -path "$ROOT_DIR/build" -prune -o \
    -path "$ROOT_DIR/DerivedData" -prune -o \
    -name Package.resolved -type f -print |
  sort |
  while IFS= read -r file; do
    shasum -a 256 "$file"
  done
}

tool_version() {
  local label="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    log "## $label"
    "$@" 2>&1 | head -n 5 | tee -a "$REPORT_FILE" || true
  else
    log "## $label: not installed"
  fi
}

log "DJConnect third-party update preflight"
log "Repository: $ROOT_DIR"
log "Report: $REPORT_FILE"
log ""

log "Tool versions before update"
tool_version "Xcode" xcodebuild -version
tool_version "Swift" swift --version
tool_version "Git" git --version
tool_version "GitHub CLI" gh --version
tool_version "notarytool" xcrun notarytool --version
tool_version "Homebrew" brew --version
log ""

before_snapshot="$(package_resolved_snapshot || true)"

found_packages=0
while IFS= read -r manifest; do
  found_packages=1
  package_dir="$(dirname "$manifest")"
  log "Updating Swift package dependencies in ${package_dir#$ROOT_DIR/}"
  (cd "$package_dir" && swift package update) 2>&1 | tee -a "$REPORT_FILE"
done < <(find "$ROOT_DIR" \
  -path "$ROOT_DIR/.git" -prune -o \
  -path "$ROOT_DIR/.build" -prune -o \
  -path "$ROOT_DIR/build" -prune -o \
  -path "$ROOT_DIR/DerivedData" -prune -o \
  -name Package.swift -type f -print | sort)

if [[ "$found_packages" == "0" ]]; then
  log "No Package.swift manifests found."
fi

found_projects=0
while IFS= read -r project; do
  found_projects=1
  log "Resolving Xcode package dependencies in ${project#$ROOT_DIR/}"
  xcodebuild -resolvePackageDependencies -project "$project" 2>&1 | tee -a "$REPORT_FILE"
done < <(find "$ROOT_DIR" \
  -path "$ROOT_DIR/.git" -prune -o \
  -path "$ROOT_DIR/.build" -prune -o \
  -path "$ROOT_DIR/build" -prune -o \
  -path "$ROOT_DIR/DerivedData" -prune -o \
  -name "*.xcodeproj" -type d -print | sort)

if [[ "$found_projects" == "0" ]]; then
  log "No Xcode projects found."
fi

if [[ "${DJCONNECT_SKIP_SYSTEM_TOOL_UPGRADE:-0}" != "1" ]]; then
  if command -v brew >/dev/null 2>&1; then
    log "Updating Homebrew metadata."
    brew update 2>&1 | tee -a "$REPORT_FILE"
    for formula in gh swiftlint xcbeautify create-dmg mas; do
      if brew list --formula "$formula" >/dev/null 2>&1; then
        log "Upgrading Homebrew formula: $formula"
        brew upgrade "$formula" 2>&1 | tee -a "$REPORT_FILE"
      fi
    done
  else
    log "Homebrew is not installed; system tool upgrade skipped."
  fi
else
  log "System tool upgrades skipped (DJCONNECT_SKIP_SYSTEM_TOOL_UPGRADE=1)."
fi

log ""
log "Tool versions after update"
tool_version "Xcode" xcodebuild -version
tool_version "Swift" swift --version
tool_version "Git" git --version
tool_version "GitHub CLI" gh --version
tool_version "notarytool" xcrun notarytool --version
tool_version "Homebrew" brew --version

after_snapshot="$(package_resolved_snapshot || true)"

if [[ "$before_snapshot" != "$after_snapshot" ]]; then
  log ""
  log "Package.resolved changed during third-party update."
  log "Update docs/THIRD_PARTY_NOTICES.md, docs/TECHNICAL_DESIGN_DECISIONS.md, CHANGELOG.md, and release notes before publishing."
  if [[ "${DJCONNECT_ALLOW_THIRDPARTY_NOTICE_DRIFT:-0}" != "1" ]]; then
    log "Set DJCONNECT_ALLOW_THIRDPARTY_NOTICE_DRIFT=1 only after the notices and release documentation have been updated."
    exit 2
  fi
fi

log ""
log "Third-party update preflight completed."
export DJCONNECT_THIRDPARTY_PREFLIGHT_DONE=1
