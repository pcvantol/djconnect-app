# Apple Moment-first Session assessment

Assignment: `DJC-APPLE-MOMENT-FIRST-SESSION-V1-20261008`.
Current boundary: source #95 protected merged as `a4cb7ed2cc332499f784eb40c822a1983a9e5289`
from independently reviewed `d57e7a441a05c455ed05e33fb6bc30fba3d74873`;
trees equal. Exact-main CI [37811802408](https://github.com/pcvantol/djconnect-app/actions/runs/37811802408)
and SHA-evidence [37812663643](https://github.com/pcvantol/djconnect-app/actions/runs/37812663643)
PASS; this separate Finalization records the software/native handoff.

## Scope and pins

One Apple writer, one pickup, branch `codex/apple-moment-first-session`, base
`2fc7fdf173d9ddb9c309e5837f1c7a449e170be9`, [PR #95](https://github.com/pcvantol/djconnect-app/pull/95).
Original generic decoder fixture pin: `ee05c9422cd7a7a08bbe769925248632fa651961`.
Actual native producer capture: `3d17994d28c71402a9076c0082c490820204ccda`,
tree `18620004f02663cc0d263073142527b95581cffa`. Core independently delivered
#1128/#1129, source merge `3ea178fa3098b2c432008827ce009f867f66f63e`,
Finalization `3488fd82ed04804973039b909f61a34e76379659` per owning
[receipt6061202421](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6061202421).
Apple imports immutable producer archives only and does not write Core.

## Native behavior

DJ-sessie and Speelt nu have separate destinations. iOS/iPadOS Meer contains
Speelt nu beside Wachtrij/Afspeellijsten. The existing native player components
were restored using pre-#48 history without replacing the entire root view.
Mac retains its standalone sidebar player. Navigation does not start/end a
Session or mutate playback; Ask DJ, Track Insight, queue, playlists and handoff
retain their routes. iPad keeps Meer visible while the other tabs can scroll.

The current DJMoment is prominent, current music provides context, and permitted
earlier contributions open native detail with a return-current action. Text,
Persona, attribution, both recording URLs and HA meaning remain server-owned.
Committed server Silence labels can appear as Flow rows without manufacturing a
Moment. Spotify is current-only, requires original album attribution plus the
loaded official full logo, and never grants historical recall. See
[asset provenance](SPOTIFY_NATIVE_ATTRIBUTION.md).

`native_delivery` v1 supplies replacement authority, current identity, Flow
membership, qualifications and original deadlines. Missing/malformed/unknown
admission denies display. Current display additionally requires playing/item
binding. Source/display expiry prunes withdrawn content including open detail.
No executable actions are inferred. There is no local intelligence or VibeCast
WebView. Moment/Presentation copies are ephemeral; no local canonical history,
new disk cache, analytics or exported personal payload.

One authenticated owner subscription uses serial awaited callbacks, Session IDs,
sequence watermarks and generation guards. Ordinary events without sequence deny
native authority and reconnect; terminal denial clears before sequence filtering.
Background/disconnect clear private copies; fresh projection is required before
recovery. A distinct native reconnect message prevents confusing missing authority
with intentional Silence. Subscription withdrawal does not declare Runtime end.
Confirmed end, unpair and lost Profile authority clear the appropriate projection.
Request invalidation also releases loading; obsolete success/error responses cannot
clear or repopulate a newer recovered Session.

## Qualification receipts

Evidence is in ignored `build/moment-first/`. Synthetic provider data comes from
actual pinned Core Runtime/HTTP/subscription capture, transported over localhost
owner HTTP/WebSocket into the real AppModel and SwiftUI. It is not a mock renderer,
live-provider test, physical-device receipt or Apple-authorized HA deployment.

- Final regular serial suite: 414 reported, 408 pass and six opt-in network skips
  (`review-final-regular-serial.log`). Localization validation: 993 keys/five languages.
- Request-loading, obsolete-error and ordinary-unsequenced-event regressions pass
  with actual HTTP/WS (`review-fix-negative-network.log`); the opt-in privacy tests
  separately cover no URLCache storage and no private response bodies in errors.
- iPhone latest lifecycle PASS (`iphone-review-fixed-lifecycle.xcresult`): two
  same-track producer contributions, both source links, background recovery,
  expiry/reconnect without revival, end and player without/during/after Session.
- English More/player/queue/playlists, open Flow detail with expiry, and real
  Spotify producer card/logo/album-link/expiry PASS (`review-native-details.xcresult`).
- iPad portrait/landscape and fixed Meer passed (`ipad-final-producer-pin.xcresult`);
  final review-fixed lifecycle is recorded separately when complete.
- Actual iPad accessibility XXXL content size, long copy and native audit
  (description/clipping/traits) PASS (`ipad-native-accessibility.xcresult`);
  its original content-size preference was restored afterward.
- Effective Reduce Motion renderer preference plus real Flow navigation PASS
  in `native-motion-lifecycle-fixed.xcresult`. This uses a DEBUG test preference;
  it does not establish physical VoiceOver traversal or OS Reduce Motion.
- Real Mac NSWindow/public accessibility sequence passes in
  `mac-review-fixed-sequence.log`; final-source sequence also PASS (`mac-final-source-sequence.log`);
  correctly configured cold no-Session state/player and metrics are recorded in
  `mac-cold-no-session.txt`, `mac-player-cold-no-session.txt` and
  `mac-cold-navigation-metrics.json`. Navigation metrics
  report zero playback mutations before explicit end. Screenshots capture actual
  windows, not ImageRenderer/offscreen substitutes.

Before screenshots are preserved from original main. After screenshots and native
accessibility state/metrics live under `build/moment-first/screenshots/` and adjacent
receipts. Earlier failed/hung attempts remain retained and are not counted as pass:
unsigned/ad-hoc Mac XCTest runner never connected; the first combined iPhone
motion/lifecycle launch failed and its reporting stalled. The isolated lifecycle
retry passed. Native Mac public-accessibility proof replaces only that UI evidence,
not a claim of successful XCTest runner or changed security configuration.

The human explicitly approved ad-hoc signing of temporary Mac test bundles and
exactly two read-only independent technical/UX reviewer agents. Their a6abe40
NO-GO findings prompted the loading/error/sequence/Silence/reconnect corrections.
Independent technical and UX reviewers both gave GO for exact corrected
`d57e7a441a05c455ed05e33fb6bc30fba3d74873`; reviews cover this source tree.

## Latest product addenda and dependent follow-up

[6061498264](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6061498264)
adds interactive text/voice Ask DJ bubbles, contextual questions, saved Sessions,
readonly historical timelines and authorized history matches/open-session actions.
These are not delivered by current #95 active Moment/Flow admission. The same
product line needs a registered dependent Apple follow-up before pickup after the
existing Core slot supplies authenticated list/detail/context/turn/order/deletion,
retention and allowed-action contracts. Targeted request is
[6064346207](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6064346207).
No fake archive/responses or local preservation of expired live payload is allowed.
New historical questions belong to current conversation; private Q/A/history never
become room Broadcast. Current independent source work remains allowed.

VibeCast alignment/Cast/LG addenda retain shared Moment identity/text/Persona/source
meaning while allowing host presentation differences. Core owns the shared web
renderer; static receiver distribution remains the controlled Pages/Cast route.
Cast SDK sender qualification and LG webOS host are separate follow-up boundaries,
not added to #95. No Core/receiver writes, extra writers, TV install or publication.

## Delivery authority

Source merge and exact-main acceptance are confirmed; this separate Finalization records the closure.
The existing main CI triggers the unchanged internal SHA-bound evidence prerelease; each concrete
source/Finalization publication requires its own owner authority. Public unsigned
release requires a version tag/manual dispatch; TestFlight/Store signing and physical
installation are outside the current grant. No protection/workflow change is needed.

The primary macOS dataless checkout WIP remains preserved by patch/new-file recovery;
only the isolated temporary Apple checkout is the source writer. Safe reconciliation
must preserve that original WIP rather than reset it during cleanup.
