#!/usr/bin/env bash
set -euo pipefail
probe_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/gh" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == api && "$2" == repositories/1265889311 ]] || exit 3
[[ "${MOCK_FAIL:-0}" != 1 ]] || exit 1
printf '%s\n' "$MOCK_RESPONSE"
MOCK
chmod +x "$test_dir/gh"
export PATH="$test_dir:$PATH"
export GH_TOKEN='synthetic-secret-must-not-appear'
good='{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false,"permissions":{"push":true}}'
check() {
  local expected="$1" data="$2" result=0
  MOCK_RESPONSE="$data" bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 || result=$?
  if [[ "$expected" == ok ]]; then [[ "$result" == 0 ]]; else [[ "$result" != 0 ]]; fi
  ! grep -Fq "$GH_TOKEN" "$test_dir/output"
}
check ok "$good"
check fail '{"id":1,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false,"permissions":{"push":true}}'
check fail '{"id":1265889311,"full_name":"other/djconnect-website","visibility":"public","private":false,"permissions":{"push":true}}'
check fail '{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"private","private":true,"permissions":{"push":true}}'
check fail '{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false,"permissions":{"push":false}}'
check fail '{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false}'
check fail 'not json'
MOCK_FAIL=1 MOCK_RESPONSE="$good" bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 && exit 1
! grep -Fq "$GH_TOKEN" "$test_dir/output"
GH_TOKEN='' MOCK_RESPONSE="$good" bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 && exit 1
printf '%s\n' 'PASS: valid write access; wrong ID, owner, visibility, permissions, invalid response, API error, missing token; no token output.'
