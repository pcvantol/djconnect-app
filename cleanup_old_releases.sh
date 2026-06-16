#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./cleanup_old_releases.sh [--keep N] [--keep-workflow-runs N] [--skip-workflow-runs] [--execute]

Examples:
  ./cleanup_old_releases.sh
  ./cleanup_old_releases.sh --keep 1
  ./cleanup_old_releases.sh --keep 2 --execute

By default this is a dry-run. It keeps the newest semantic-version tag/release
and newest GitHub Actions workflow run, then deletes older matching vX.Y.Z
GitHub releases, remote tags, local tags and old GitHub Actions workflow runs
only when --execute is passed.
EOF
}

KEEP=1
KEEP_WORKFLOW_RUNS=1
SKIP_WORKFLOW_RUNS=false
EXECUTE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]]; then
        echo "--keep requires a positive number." >&2
        exit 64
      fi
      KEEP="$2"
      shift 2
      ;;
    --keep-workflow-runs)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]]; then
        echo "--keep-workflow-runs requires a positive number." >&2
        exit 64
      fi
      KEEP_WORKFLOW_RUNS="$2"
      shift 2
      ;;
    --skip-workflow-runs)
      SKIP_WORKFLOW_RUNS=true
      shift
      ;;
    --execute)
      EXECUTE=true
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

if [[ ! -d ".git" || ! -f "project.yml" || ! -d "DJConnectApp.xcodeproj" ]]; then
  echo "Run this script from the djconnect-app repository root." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI 'gh' is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

run() {
  echo "+ $*"
  if [[ "$EXECUTE" == true ]]; then
    "$@"
  fi
}

TAGS=()
while IFS= read -r tag; do
  [[ -n "$tag" ]] && TAGS+=("$tag")
done < <(
  git ls-remote --tags --refs origin 'v*' \
    | awk '{print $2}' \
    | sed 's#refs/tags/##' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V -r
)

DELETE_TAGS=()

if [[ "${#TAGS[@]}" -eq 0 ]]; then
  echo "No semantic version tags found on origin."
else
  echo "Newest tags/releases to keep:"
  printf '  %s\n' "${TAGS[@]:0:KEEP}"

  if [[ "${#TAGS[@]}" -le "$KEEP" ]]; then
    echo "No old releases/tags to delete."
  else
    DELETE_TAGS=("${TAGS[@]:KEEP}")
  fi
fi

if [[ "${#DELETE_TAGS[@]}" -gt 0 ]]; then
  echo
  if [[ "$EXECUTE" == true ]]; then
    echo "Deleting old releases/tags:"
  else
    echo "Dry-run. Would delete old releases/tags:"
  fi
  printf '  %s\n' "${DELETE_TAGS[@]}"
  echo

  for tag in "${DELETE_TAGS[@]}"; do
    if gh release view "$tag" >/dev/null 2>&1; then
      run gh release delete "$tag" --yes
    else
      echo "+ skip missing GitHub release $tag"
    fi
    run git push --delete origin "$tag"
    if git rev-parse "$tag" >/dev/null 2>&1; then
      run git tag -d "$tag"
    else
      echo "+ skip missing local tag $tag"
    fi
  done
fi

if [[ "$EXECUTE" == false ]]; then
  echo
  echo "Dry-run release/tag cleanup complete."
fi

if [[ "$SKIP_WORKFLOW_RUNS" == true ]]; then
  exit 0
fi

WORKFLOW_RUNS=()
while IFS= read -r run_id; do
  [[ -n "$run_id" ]] && WORKFLOW_RUNS+=("$run_id")
done < <(
  gh run list --repo pcvantol/djconnect-app --limit 200 --json databaseId \
    --jq ".[${KEEP_WORKFLOW_RUNS}:][].databaseId"
)

if [[ "${#WORKFLOW_RUNS[@]}" -eq 0 ]]; then
  echo "No old workflow runs to delete."
  exit 0
fi

echo
if [[ "$EXECUTE" == true ]]; then
  echo "Deleting old workflow runs, keeping newest $KEEP_WORKFLOW_RUNS:"
else
  echo "Dry-run. Would delete old workflow runs, keeping newest $KEEP_WORKFLOW_RUNS:"
fi
printf '  %s\n' "${WORKFLOW_RUNS[@]}"

for run_id in "${WORKFLOW_RUNS[@]}"; do
  run gh run delete "$run_id" --repo pcvantol/djconnect-app
done

if [[ "$EXECUTE" == false ]]; then
  echo
  echo "Dry-run complete. Re-run with --execute to delete old releases/tags/workflow runs."
fi
