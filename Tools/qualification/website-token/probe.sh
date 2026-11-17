#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${GH_TOKEN:-}" ]]; then
  printf '%s\n' 'Website token unavailable.' >&2
  exit 1
fi
if ! metadata="$(gh api repositories/1265889311 2>/dev/null)"; then
  printf '%s\n' 'Website repository access could not be verified.' >&2
  exit 1
fi
if ! jq -e '(.id == 1265889311) and (.full_name == "djconnect-music-dj/djconnect-website") and (.visibility == "public") and (.private == false) and (.permissions.push == true)' <<<"$metadata" >/dev/null 2>&1; then
  printf '%s\n' 'Website identity or repository write permission was not verified.' >&2
  exit 1
fi
printf '%s\n' 'Verified repository write permission for the intended public website.'
printf '%s\n' 'Protected-main bypass and actual publication were not tested.'
