# Playback volume capability and presentation

Owner report: Bluetooth playback rejects remote volume with raw English
`Player command failed: Cannot control device volume`.

Apple40224 consumes existing device/output supports_volume capability in both
Now Playing control layouts. Explicit false hides the complete volume row;
unknown legacy capability retains controls only with an actual volume value.
Known refusal also hides volume for the affected playback device, backend revision
and output-selection generation. It does not disable unrelated output devices.
Commit and delayed command paths recheck capability before sending. No local
phone Bluetooth inference is applied to remote speakers.

The exact refusal maps to a plain instruction to use device controls in nl/en/de/
fr/es, and is no longer treated as a music-backend outage. No Core contract change.

Validation:3 targeted tests PASS, including five localization cases, explicit
capability false/true/absent and refusal followed by a different controllable
output. Logs: /private/tmp/djc-volume40224-tests-final.log. iOS/macOS signed builds
PASS: /private/tmp/djc-volume40224-{ios,mac}-final.log. No physical Bluetooth
volume adjustment or audible/runtime acceptance claimed.

## Remaining raw current-track header percentage —40233

Owner screenshot showed the separate Session music-context footer still reading
playback.volumePercent directly. It now renders the shared qualified current
volume presentation: matched local Bluetooth route -> Bluetooth rune, otherwise
valid controllable percentage -> percentage, otherwise '-'. It does not clamp
invalid/unsupported data into a plausible percentage. Inactive devices do not
supply a current percentage. A genuine supported speaker at100 remains100.
Shared Bluetooth matching also uses matching output type when playback omits it;
no audio session is activated or route modified to discover Bluetooth.
The common Bluetooth shape is reused by the footer and output list. Regression
includes unsupported100, missing volume, actual supported100 and inactive37.

40233 validation:40 output/volume tests in2 suites PASS; signed ordinary iOS and
Mac builds/deep strict signatures PASS. Installed/read back40233 on iPhone/iPad
and closed Mac mini with previous40232 retained. No physical Bluetooth-render
acceptance inferred from this build/predicate evidence.

Later actual iPhone native Persona-popover screenshot (40234) was exported and
visually inspected: current active output iPhone shows the Bluetooth rune in the
Session track footer instead of100%. This closes that native rendered-state check
for the observed route, not all Bluetooth hardware combinations or audibility.
