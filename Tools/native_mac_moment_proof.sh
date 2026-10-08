#!/bin/zsh
set -e
cd "${0:A:h:h}"
proof_ui=${1:?compiled native_mac_moment_ui path required}
proof_pid=${2:?own temporary proof PID required}
proof_window=${3:?own native main window ID required}
wait_native() {
 for proof_try in {1..30}; do
  "$proof_ui" "$proof_pid" read > build/moment-first/mac-proof-state.txt
  if rg -q -- "$1" build/moment-first/mac-proof-state.txt; then return 0; fi
  sleep 0.2
 done
 return 1
}
curl --fail --max-time 5 -s http://127.0.0.1:18787/fixture/native_reset > /private/tmp/djc-mac-fixture-reset.json
"$proof_ui" "$proof_pid" press Vernieuwen
wait_native 'Even meekijken in de credits'
cp build/moment-first/mac-proof-state.txt build/moment-first/mac-current-01.txt
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-01-current.png
curl --fail --max-time 5 -s http://127.0.0.1:18787/fixture/advance > /private/tmp/djc-mac-fixture-advance.json
wait_native 'Nora Vale kwamen we eerder'
cp build/moment-first/mac-proof-state.txt build/moment-first/mac-current-02.txt
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-02-current.png
"$proof_ui" "$proof_pid" press 'Speelt Nu'
wait_native 'Slow Lanterns'
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-03-player-active-session.png
"$proof_ui" "$proof_pid" press 'DJ-sessie'
"$proof_ui" "$proof_pid" press 'Trackverhaal, Even de credits erbij'
wait_native 'Even meekijken in de credits'
cp build/moment-first/mac-proof-state.txt build/moment-first/mac-flow-detail.txt
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-02b-flow-detail.png
"$proof_ui" "$proof_pid" press 'Terug naar de actuele bijdrage'
wait_native 'Nora Vale kwamen we eerder'
curl --fail --max-time 5 -s http://127.0.0.1:18787/fixture/metrics > build/moment-first/mac-navigation-metrics.json
curl --fail --max-time 5 -s http://127.0.0.1:18787/fixture/expire > /private/tmp/djc-mac-fixture-expire.json
sleep 0.5
"$proof_ui" "$proof_pid" read > build/moment-first/mac-expired.txt
if rg -q 'Nora Vale|MusicBrainz' build/moment-first/mac-expired.txt; then exit 2; fi
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-03a-source-expiry.png
curl --fail --max-time 5 -s http://127.0.0.1:18787/fixture/reconnect > /private/tmp/djc-mac-fixture-reconnect.json
sleep 2
"$proof_ui" "$proof_pid" read > build/moment-first/mac-reconnected.txt
if rg -q 'Nora Vale|MusicBrainz' build/moment-first/mac-reconnected.txt; then exit 3; fi
"$proof_ui" "$proof_pid" press 'Sessie beëindigen'
wait_native 'Start DJ-sessie'
"$proof_ui" "$proof_pid" press 'Speelt Nu'
wait_native 'Slow Lanterns'
screencapture -x -l "$proof_window" build/moment-first/screenshots/mac-04-player-ended-session.png
print 'MAC_NATIVE_REAL_WINDOW_SEQUENCE_PASS'
