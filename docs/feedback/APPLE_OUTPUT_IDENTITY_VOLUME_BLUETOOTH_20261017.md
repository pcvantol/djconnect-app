# Output identity, reported volume and local Bluetooth

Owner requested a dash instead of an unavailable current output volume, no opaque
GUID labels, and a Bluetooth symbol for the active local iPhone output if detected.

Apple40225 removes the output-list overwrite from playback.volumePercent: it may
be stale or belong to a route without remote volume support. Render valid reported
output volume only when supports_volume is not false; otherwise show '-'. A known
volume refusal also suppresses the active matching output percentage.

Output name fallback previously exposed transport IDs when name was missing.
Opaque hex identifiers are not display names. Recover an earlier friendly name or
current playback name only by exact stable ID, otherwise use a five-language name
unavailable label. The transport ID is retained for identity, not invented as a
friendly name. No cross-device name matching is used for name restoration.

On iOS read AVAudioSession.currentRoute without activating/changing audio. Observe
route changes. Show a Bluetooth rune only for a Bluetooth A2DP/HFP/LE route and an
active phone/tablet output matching both current playback ID and local device
name. Remote speakers and other/inactive phones retain their normal icons.
An ambiguous/nonmatching device remains its normal icon; no inferred Bluetooth
provider capability or Core mutation. Physical Bluetooth acceptance remains open.

User explicitly authorized forwarding the source defects to the existing Core
writer. Sent: source Spotify normalization currently derives supports_volume from
is_restricted alone; missing names/volume defaults also require authoritative
producer correction. No second Core writer or direct HA config change.

Validation:5 targeted tests PASS, including5 locale cases; existing output/volume
regression selection39 tests in2 suites PASS (djc-output40225-regression.log).
Both signed40225 builds PASS. iOS40226 additionally uses the same qualified local
Bluetooth-route match to suppress volume controls/percent before the first remote
volume refusal, even when the old backend reports supports_volume=true.
