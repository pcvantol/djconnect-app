#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-}"
DERIVED_DATA="$ROOT_DIR/.release/DerivedData"
SKIP_TESTS=0
SKIP_BUILDS=0
SKIP_SOURCE_RELEASE=0
PUBLIC_MACOS=0
CLEANUP=1
KEEP_RELEASES=1
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: ./release.sh <version> [options]

Options:
  --skip-tests            Skip swift test
  --skip-builds           Skip unsigned iOS/macOS build validation
  --skip-source-release   Do not create/push tag or private GitHub source release
  --public-macos          Build, notarize and upload the public macOS binary
  --cleanup               Run cleanup_old_releases.sh after release (default)
  --no-cleanup            Skip release/tag/workflow cleanup
  --keep <n>              Number of releases/tags to keep during cleanup (default: 1)
  --dry-run               Print release actions without creating GitHub releases

Examples:
  ./release.sh 3.1.15
  ./release.sh 3.1.15 --public-macos --keep 1
USAGE
}

shift_version() {
  if [[ -z "$VERSION" || "$VERSION" == -* ]]; then
    usage
    exit 2
  fi
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-tests) SKIP_TESTS=1 ;;
      --skip-builds) SKIP_BUILDS=1 ;;
      --skip-source-release) SKIP_SOURCE_RELEASE=1 ;;
      --public-macos) PUBLIC_MACOS=1 ;;
      --cleanup) CLEANUP=1 ;;
      --no-cleanup) CLEANUP=0 ;;
      --keep)
        KEEP_RELEASES="${2:-}"
        shift
        ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 2
        ;;
    esac
    shift
  done
}

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@"
  fi
}

shift_version "$@"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like 3.1.15" >&2
  exit 2
fi

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.release"

echo "DJConnect app release $VERSION"
run git diff --check

if [[ "$SKIP_TESTS" -eq 0 ]]; then
  run swift test --no-parallel
fi

if [[ "$SKIP_BUILDS" -eq 0 ]]; then
  run rm -rf "$DERIVED_DATA"
  run xcodebuild \
    -project DJConnectApp.xcodeproj \
    -scheme DJConnectMac \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA/mac" \
    CODE_SIGNING_ALLOWED=NO \
    clean build
  run xcodebuild \
    -project DJConnectApp.xcodeproj \
    -scheme DJConnectIOS \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA/ios" \
    CODE_SIGNING_ALLOWED=NO \
    clean build
fi

if [[ "$SKIP_SOURCE_RELEASE" -eq 0 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit changes before creating a release." >&2
    exit 1
  fi
  TAG="v$VERSION"
  if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    run git tag "$TAG"
  fi
  run git push origin HEAD
  run git push origin "$TAG"
  if gh release view "$TAG" --repo pcvantol/djconnect-app >/dev/null 2>&1; then
    echo "GitHub release $TAG already exists in pcvantol/djconnect-app"
  else
    NOTES_FILE="$ROOT_DIR/.release/release-$VERSION-notes.md"
    printf "# DJConnect App %s\n\nSee CHANGELOG.md for details.\n" "$VERSION" > "$NOTES_FILE"
    run gh release create "$TAG" \
      --repo pcvantol/djconnect-app \
      --title "DJConnect App $VERSION" \
      --notes-file "$NOTES_FILE"
  fi
fi

if [[ "$PUBLIC_MACOS" -eq 1 ]]; then
  run "$ROOT_DIR/Tools/release/release_macos_public.sh" --version "$VERSION"
fi

if [[ "$CLEANUP" -eq 1 ]]; then
  run "$ROOT_DIR/cleanup_old_releases.sh" --keep "$KEEP_RELEASES" --execute
fi

echo "Release workflow completed for $VERSION"
