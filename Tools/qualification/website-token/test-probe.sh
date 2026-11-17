#!/usr/bin/env bash
set -euo pipefail
probe_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
args=" $* "
[[ "$args" == *' --disable --config - '* && "$args" == *' https://api.github.com/repositories/1265889311 '* ]] || exit 3
[[ "$args" != *"$GH_TOKEN"* ]] || exit 4
IFS= read -r auth
[[ "$auth" == "header = \"Authorization: Bearer $GH_TOKEN\"" ]] || exit 5
out=''
while (($#)); do if [[ "$1" == '--output' ]]; then out="$2"; shift; fi; shift; done
[[ -n "$out" ]] || exit 6
printf '%s' "${MOCK_BODY:-}" >"$out"
printf '%s' "${MOCK_STATUS:-200}"
printf 'sensitive-upstream-error-%s\n' "$GH_TOKEN" >&2
exit "${MOCK_EXIT:-0}"
MOCK
chmod +x "$test_dir/curl"
export PATH="$test_dir:$PATH" RUNNER_TEMP="$test_dir" GH_TOKEN='synthetic_secret_must_not_appear'
good='{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false,"permissions":{"push":true}}'
check() {
 local expected="$1" status="$2" body="$3" expected_text="$4" result=0
 MOCK_STATUS="$status" MOCK_BODY="$body" bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 || result=$?
 if [[ "$expected" == ok ]]; then [[ "$result" == 0 ]]; else [[ "$result" != 0 ]]; fi
 grep -Fq "$expected_text" "$test_dir/output"
 ! grep -Fq "$GH_TOKEN" "$test_dir/output"
 ! grep -Fq 'sensitive-upstream-error' "$test_dir/output"
 ! grep -Fq 'sensitive-response-body' "$test_dir/output"
 [[ $(find "$test_dir" -maxdepth 1 -type f | wc -l | tr -d ' ') == 2 ]]
}
check ok 200 "$good" 'Verified repository write permission'
for code in 401 403 404 429 500 502 503 504; do check fail "$code" "sensitive-response-body-$GH_TOKEN" "HTTP $code"; done
check fail '418' "sensitive-response-body-$GH_TOKEN" 'unrecognized HTTP status'
check fail "403$GH_TOKEN" "sensitive-response-body-$GH_TOKEN" 'unrecognized HTTP status'
check fail 200 '{"id":1,"permissions":{"push":true}}' 'identity or repository write permission'
check fail 200 '{"id":1265889311,"full_name":"other/djconnect-website","visibility":"public","private":false,"permissions":{"push":true}}' 'identity or repository write permission'
check fail 200 '{"id":1265889311,"full_name":"djconnect-music-dj/djconnect-website","visibility":"public","private":false,"permissions":{"push":false}}' 'identity or repository write permission'
check fail 200 "invalid-sensitive-response-body-$GH_TOKEN" 'identity or repository write permission'
MOCK_STATUS=000 MOCK_EXIT=7 MOCK_BODY="sensitive-response-body-$GH_TOKEN" bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 && exit 1
grep -Fq 'network or TLS error' "$test_dir/output"
! grep -Fq "$GH_TOKEN" "$test_dir/output"
! grep -Fq 'sensitive-upstream-error' "$test_dir/output"
GH_TOKEN='' bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 && exit 1
grep -Fq 'token unavailable' "$test_dir/output"
GH_TOKEN='bad"token' bash "$probe_dir/probe.sh" >"$test_dir/output" 2>&1 && exit 1
! grep -Fq 'bad"token' "$test_dir/output"
printf '%s\n' 'PASS: allowed HTTP codes, success, identity and permission failures, transport errors, malformed statuses, input validation, cleanup and secret/body redaction.'
