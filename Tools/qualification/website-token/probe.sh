#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${GH_TOKEN:-}" ]]; then
  printf '%s\n' 'Website token unavailable.' >&2
  exit 1
fi
# GitHub tokens contain no config metacharacters. Reject anything unexpected
# before supplying the secret to curl through standard input, not argv.
if [[ ! "$GH_TOKEN" =~ ^[A-Za-z0-9_]+$ ]]; then
  printf '%s\n' 'Website token format is not supported.' >&2
  exit 1
fi
umask 077
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  response_file="$(TMPDIR="$RUNNER_TEMP" mktemp)"
else
  response_file="$(mktemp)"
fi
trap 'rm -f -- "$response_file"' EXIT
status=''
if ! status="$(printf 'header = "Authorization: Bearer %s"\n' "$GH_TOKEN" | curl --disable --config - --silent --show-error --proto '=https' --max-time 15 --output "$response_file" --write-out '%{http_code}' --header 'Accept: application/vnd.github+json' --header 'User-Agent: djconnect-website-access-check' 'https://api.github.com/repositories/1265889311' 2>/dev/null)"; then
  printf '%s\n' 'Website repository access could not be verified (network or TLS error).' >&2
  exit 1
fi
case "$status" in
  200) ;;
  401|403|404|429|500|502|503|504)
    printf 'Website repository access could not be verified (HTTP %s).\n' "$status" >&2
    exit 1
    ;;
  *)
    printf '%s\n' 'Website repository access could not be verified (unrecognized HTTP status).' >&2
    exit 1
    ;;
esac
if ! jq -e '(.id == 1265889311) and (.full_name == "djconnect-music-dj/djconnect-website") and (.visibility == "public") and (.private == false) and (.permissions.push == true)' "$response_file" >/dev/null 2>&1; then
  printf '%s\n' 'Website identity or repository write permission was not verified.' >&2
  exit 1
fi
printf '%s\n' 'Verified repository write permission for the intended public website.'
printf '%s\n' 'Protected-main bypass and actual publication were not tested.'
