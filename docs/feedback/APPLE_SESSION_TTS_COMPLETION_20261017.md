# Session TTS completion

Owner explicitly requests completion including actual client delivery. Existing
same writer; settings3 draft implementation and accumulated authorized UI fixes
are preserved. Core1329ad1 settings3/prepare3 contract remains producer authority.

Close the concrete manual-play bug: source admission may last days whereas local
playback tickets admit at most300 seconds. Bound each attempt to min(original
source deadline, now+300), then shorten to the prepared asset deadline. Never
extend source/asset rights or fabricate missing descriptors. Validate exact text,
identity/revisions, settings/provider fences and current retained owner after each
await. Single-output coordinator handles replacement/stop/cancel/expiry; cleanup
must also run on early returns. Manual actions stay local with autoplay disabled.

Show Play/Replay/Stop and preparation state per contribution; do not hide qualified
controls merely because settings are loading/review-required. Link to the shared
editor for explicit required choices. No silent six-field migration acceptance.
Test exact prepare3 payload and denied/fenced/expired cases, private serialization,
local output behavior and native five-language integration. Build/install only a
qualified candidate; installed visual, prepared bytes, actual output and audible
human confirmation remain distinct. No scanner/runtime or source publication.

Full-suite audit exposed that settings3 capability adoption had disabled existing
explicit Core1 Mood/Persona/Presence contracts. Restore only their previously
qualified capability branches for servers not advertising settings3. A settings3
producer sets a separate required flag: failure/absence of the shared read never
falls back to legacy writes. Shared quick controls additionally require the exact
currently displayed Session in the shared snapshot. This preserves older producer
compatibility without introducing a second settings3 writer or local defaults.

Additional explicit owner requirement: earlier Sessions must synthesize again on
demand when the previous asset expired. Archive actions now use the exact retained
entry identity/text/retention under the current authorized owner, independent of
a missing/expired old audio descriptor. Only an explicit tap calls prepare3; Core
reauthorizes and resolves the immutable contribution, and returns a new short
asset grant. Reads never synthesize. No expired byte URL is reused, no arbitrary
caller text is sent, and expired/deleted original entries remain unavailable.

Qualification 40212: 713 tests PASS with --no-parallel (explicit per-test race and
ABA tests still exercise concurrency); 1241 localized keys PASS; signed iOS+Watch
and Mac builds PASS and deep strict signatures PASS. Exact151-source-file stage
match in build/recovery/tts40212-source-manifest-20261017.json. Initial unrestricted
parallel run exposed global two-transfer test-budget contention and a fixed300ms
artwork-confirmation assertion under aggregate load; neither is reclassified as a
passing parallel run. Optional HTTP route absence incorrectly reported offline;
transport now retains the reachable origin and never retries the refused request.
New local/remote route tests verify this behavior.

Installed40212/read back on iPhone and iPad; Mac installed40212, strict signature
rechecked, prior app retained in build/recovery/DJConnect-before40212.app. No
MacBook install claimed. Native iPhone test proves TTS buttons visible, but the
positive enabled assertion FAILS because actual Core requires six-field activation.
Read-only native Jouw DJ inspection PASS; actual proposals: home_dj, provider_default,
default gender, energy, presenter, client_device. User was asked explicitly to
activate these exact six values. No PATCH/confirmation was performed or assumed.
Until that response, real prepare/audio/replay/earlier-Session and audible acceptance
are still pending. Initial screenshot-result collection stalled; own completed
failing test was interrupted. Subsequent text-only native inspection completed
and saved normally (/private/tmp/djc-tts40212-iphone-settings-labels.xcresult).

Follow-up native40218: owner explicitly approved the six proposed values; native
confirmation now reports `Opgeslagen voor dit profiel.` (40213 confirm2 result).
40214 moved the white44pt play control inside each speakable bubble at bottom
right; preparing and Stop replace that same control with accessible state.
Current screenshot exported and visually inspected from
/private/tmp/djc-tts40218-qualified-play2.xcresult. Playback observations were
incorrectly offered as retained TTS sources; removed, with passing negative
admission regression. Core only accepts retained DJ Moment/assistant contributions.

Actual device exposed a second timing defect: prepared audio is issued later
than the attempt timer and may have expiry > attempt+300 by preparation time.
shortenDeadline rejected that valid result. Preserve the original attempt cap,
shorten to min(prepared expiry, attempt expiry). The clean staged targeted tests
pass2/2 (/private/tmp/djc-tts40218-regression.log), following the earlier713-suite
qualification; no claim that the full suite was rerun after these narrow fixes.
40218 signed iOS/Mac builds pass. Installed40218 on iPhone and iPad and read back.
Mac build40218 is built but the installed Mac remains40212 at this point.

Native iPhone retained Wikidata entry-d704df2ccfe954cf827a4487a7af4bb5:
ACTUAL_PLAYING, STOP_TAPPED, ACTUAL_REPLAY_PLAYING, TEST SUCCEEDED in
/private/tmp/djc-tts40218-qualified-play2.log. This verifies actual AVAudioPlayer
output state, not independent human audible confirmation. iPad UI automation
initialization timed out before product tests; no iPad runtime PASS inferred.
Archive qualification remains in progress.

A different current Spotify-backed Moment returns Core unavailable reason
source_processor_not_qualified with configured OpenAI TTS. Owner explicitly asks
to remove that Core locality restriction for any configured HA provider, and
rejected switching the provider as a workaround. See APPLE_TTS_PROVIDER_FOLLOWUP_20261017.md.

Archive native qualification PASS: /private/tmp/djc-tts40218-archive.xcresult
and log. Opened ended session-2c13edf6e33849b7a4d6c3478dfd4996, explicitly
prepared its retained CC0 entry-b982fccc53b551c4b6bfec9ec829d5eb from2026-10-16
22:42UTC, and observed ARCHIVED_ACTUAL_PLAYING before Stop. The old short
audio grant cannot be reused overnight; this confirms on-demand prepare/output.
No archive open/read caused synthesis.

Owner explicitly approved routing his provider restriction removal request to
the existing Core task. Complete request sent successfully to
01a120e2-b557-76c3-8568-129dbce2f2d2 (Pak VibeCast shared renderer op). No second
Core writer or direct HA provider/configuration edit. Follow-up provider-wide
source delivery and physical Spotify/OpenAI acceptance remain pending there.

Final40218 Mac installation: actual /Applications/DJConnect.app updated after
confirming it was not running; previous40212 preserved as
build/recovery/DJConnect-before40218.app. Strict deep signatures pass for iOS and
Mac, before/after installation. No MacBook installation claimed. Manifest
build/recovery/tts40218-source-manifest-20261017.json proves151 source/config
files match the staged build source.

iPad native automation retry also timed out enabling automation mode before
product-test execution. Installed40218/readback is PASS; real iPad audio is not
qualified. Preserve logs/results rather than classifying driver failure as a
product failure or as successful playback.
