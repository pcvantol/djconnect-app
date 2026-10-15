# Apple feedback: current disposition — 2026-10-15

This is the current view of the owner's complete feedback list and Apple lane #87.
It supersedes the intermediate counts and candidate pins in
[the chronological worklist](APPLE_FEEDBACK_20261014.md). A source correction is
not an installed fix. The owner subsequently authorized installation on iPad, iPhone, MacBook and Mac mini.
The initial installation checkpoint was build40060 on all four devices. See the
latest checkpoint below for current device versions. Installation is not acceptance
of every reported bug. Source publication/CI/merge and speculative re-pair remain
outside the current authorization.

Sole writer: `build/apple-40017-recovery/source`, branch
`codex/apple-dj-presence-v1`, starting HEAD `3c89327`. Original root WIP and the
extra untracked Xcode projects are preserved. The disposable `/private/tmp`
checkout is byte-copied build input, not another source writer.

## Latest checkpoint: Hybrid / About, build40064

Owner explicitly requested the transportslice, accurate About connection details,
and a Details → About action in every non-green connection popover.

- Source: automatic paired Hybrid actions, original-operation recovery, separate
  Broadcast cursor recovery, readonly automatic transport settings and About
  route/transport/origin reporting. See HYBRID_TRANSPORT_APPLE_ADOPTION_V1.md.
- Five-language localization validation:1134 keys PASS; diff whitespace PASS.
- Native unsigned and Apple Development signed Mac/iOS builds40064 PASS.
- Mac mini ordinary app40064 installed and launched PID46894. Strict/deep
  signature, exact installed-file hashes, entitlement and preference preservation
  PASS; receipt /private/tmp/djc-hybrid-mac-install3.json. Normal quit was blocked
  by crash/setup sheets; optional crash sheet was dismissed with Niet nu, then
  the app's own App afsluiten button completed normal termination. No force kill,
  token restore or re-pair. It remains unpaired and shows the required setup sheet.
- Physical iPad40064 installed and launched via devicectl. Screenshot
  /private/tmp/djc-hybrid-ipad-40064.png shows the real active Session behind the
  existing possible-crash sheet, with an external-route globe. This is installed
  observation, not end-to-end proof of Details navigation or network transitions.
- MacBook last verified40062; normal replacement was blocked by setup UI earlier.
  iPhone last verified40060, currently unavailable in a fresh device inventory.
- Final software regression:572 tests PASS in31.028s, including route-origin
  selection and clearing on background. Log: /private/tmp/djc-hybrid-final-tests.log.
  Native action/network-transition acceptance remains OPEN; the injected wire
  tests cannot qualify physical TLS, LAN-to-external switching or energy use.

The current Mac pairing401 issue and iPad crash overlay are not reported as fixed
by this transport/About candidate. No APNs testpush is claimed.

## Per-report disposition

| Owner report | Local correction / verified scope | Still required |
| --- | --- | --- |
| Output change delayed / two selected speakers | Exact pending/confirmed selection, obsolete-response fencing, immediate device readback | Real output-device acceptance |
| Selected speaker says Actief | Current volume replaces the redundant word | Native/device acceptance |
| Inconsistent About/Legal/Privacy gaps | Current source uses24-point outer section spacing and shared glass surfaces | Side-by-side acceptance on installed candidate |
| Context speech balloon does not open Ask DJ on Mac | Native context/navigation route preserved and covered by source tests | Installed click-through |
| Discover Play now does nothing | Await actual action outcome; retain sheet and visible failure on refusal | Actual playback/provider acceptance |
| Missing Music DNA artist/track art | Safe relative URLs and exact same-Profile/URI/kind authorized Discovery references; numeric Unix expiry fixed | Producer must actually supply an eligible reference; no name inference |
| Discover sections need own glass card | Separate Rediscover / Artists to explore section surfaces | Native acceptance |
| Discover thumbnails disappear | Original image lease, bounded GET renewal and resume/generation fencing | Real asset/source acceptance |
| Ask DJ speaker choices disappear | Current response RAM overlay survives reduced history, numeric timestamp decoding, frozen action identity and inherited original lifetime | Actual server choices and device acceptance |
| Internal command appears in conversation | Never use the technical command as user-visible fallback text | Installed acceptance |
| Ask DJ artwork briefly appears then disappears | Current response retains original image/action rights in RAM; expiry/scope withdrawal still removes it | Valid server grants and actual image acceptance |
| DJ-session DJMoment artwork absent | Existing explicit subject-bound consumer design; no borrowed playback/Discover artwork | Core early schema, assets, real transport fixtures/checksums and exact pin remain missing |
| Track Insight data absent | Explicit Moment→detail uses exact subject A; qualified CC0 credit and source shown separately; unknown measurements stay unknown | Qualified musical analysis/measurements from Core and joint acceptance |
| Subtle hero animation | Shared subtle motion with Reduce Motion / inactive-scene handling | Native accessibility/visual acceptance |
| Mood labels/icons/track need white | White unselected labels, glyphs, markers and rail | Installed visual acceptance |
| Now Playing uses wrong background / Mac does not follow artwork | Actual image palette on both platforms; no Mood blend; neutral missing-art state | Physical album changes incl. brown/cream cover |
| Presence UX should match Mood | Shared compact five-step control; no Confirmed row or explanatory footer; accessible adjustable value retained | Native interaction/accessibility acceptance |
| Connection status is ambiguous | One14-state label/icon/colour mapping; no second health dot | Native/device state acceptance |
| Connection indicator placement / requested pages | Trailing on DJ-session, Now Playing, Track Insight, Discover, Ask DJ, Music DNA, Queue and Playlists; omitted from Earlier Sessions | Native page/toolbar acceptance |
| Saved Sessions refresh errors | Keep confirmed readonly rows on transient failure; superseded/cancelled read does not create false error; authority refusal still clears | Real history endpoint acceptance |
| Session progress lags after seeking | Shared exact-track pending position, then confirmed server position | Actual seek and cross-screen acceptance |
| Presenter / other modes only show observed playback | No fabricated DJMoments. Authorized one-shot projection had2Moments,2presentations,10admissions, but no current Moment/grant | Core planner/publication causality and actual contribution frequency remain unproven |
| Cross-device Session only appears after refresh | Bounded foreground discovery via existing10-second coordinator, independent of known session/playback | Real Mac/iPhone/iPad start/end/successor acceptance; owner confirmed sharing after matching Profiles |
| Splash lower image outdated | Reuses DJ-session welcome hero | Installed acceptance |
| Strange Mac mini Sessieverloop and detail popups | Removed alternate legacy layout; normal Session screen plus honest history recovery | Limited isolated native proof exists; ordinary40060 layout acceptance still separate |
| Pi VibeCast code fails | Approval never automatically replayed; exact Session acknowledgment; distinct unavailable-code/unconfirmed outcome | Current receiver code and actual handoff/Pi render |
| Push Action needed | Distinguish missing issuer configuration, OS/APNs, transport and explicit registration; safe details and retry; receive/tap coalescing fixed | Authoritative trusted issuer configuration/deployment and real APNs delivery |
| Music DNA fails after off/on | Exact409context refusal withdraws old data and retries boundedly; unknown state does not claim opt-out | Core must determine rejecting context predicate; no reset/re-pair bypass |
| Current artist text/voice fails | Final exact Core private-response fixture adopted; older history revisions no longer reject current private reply as revision0 | Installed final Core and actual microphone/reply acceptance |

## Lane #87 continuation

Current lane comments were reread without posting or sending a message. The Core
queue remains separately owned; do not duplicate its writer or substitute Apple
for its Hybrid/artwork work.

- Moment→Track Insight producer: Core #1166, exactmain
  `7698961ec4fc7f93d1afa155aa73416a35604ac3`;
  `Tests/Fixtures/moment-insight-core-producer.json` SHA256
  `9be892d55c8aaee4871e54ac68ed04945fb0676ce5472e2091a83ee66b2151a8`.
  Navigation is inert until click, capability/version gated, exact immutable
  reference, no current-playback substitution. Detail is RAM/view scoped, no
  widget/history/share storage, and original publication/source deadline cannot
  be extended by retry. A valid successor, end, background, forbidden/expired
  source, changed media identity and unavailable runtime are separate tests.
- Frozen search/refinement/selection actions inherit their original result-set
  deadline even when selection omits result_set. Repeat cannot extend it;
  revoked/expired grants cannot be restored by subsequent response or scope change.
- Current-artist producer: Core #1168 exactmain
  `eeb1c7e763f72ee346ec8eabb52e1c7d87d39433`, fixture SHA256
  `6fac84203cc3ce18c380895a5e59dcbcf93dc038034bc9f4be8f5c5ca8e14536`.
  Final additive private_ephemeral metadata does not require the earlier optional
  history_persisted=false marker. Ordinary history version/owner/epoch checks remain.
- Session/Moment artwork assignment
  `DJC-APPLE-SESSION-MOMENT-ARTWORK-V1-20261014` remains selected/queued pending
  the explicit early Core inputs listed in
  [the adoption design](SESSION_MOMENT_ARTWORK_ADOPTION.md). No DTO is invented.

## New native findings and evidence

A separately identified temporary Mac app used only synthetic loopback owner
projections and the exact sanitized Core detail fixture. Native AX and screenshot
confirmed: zero detail requests before click; one after click; A stays A while B
plays; Close returns to the same Session; zero playback mutations. This is
`SYNTHETIC_NATIVE_RENDERER_PROOF`, not real Core/provider/microphone/installed proof.
Files: `/private/tmp/djc-insight-native-{before,detail,after-B,return}.txt`,
`/private/tmp/djc-insight-native-detail.png`,
`/private/tmp/djc-insight-native-receipt.json`. That app and its local fixture
were stopped; the ordinary DJConnect process was not replaced or restarted.

The native screenshot exposed Core summary/full_text strings containing serialized
language dictionaries. Apple does not evaluate or extract prose from that debug
representation. For the existing qualified_credit_and_interpretation_v1 contract,
verified_context is rendered only with measured_audio=false plus valid HTTPS CC0
source attribution; normal prose interpretation stays separate. A technical-only
explicit detail without this qualified fallback is refused. Energy/danceability/
intensity remain absent; no local analysis was created. The final updated native
screenshot is recorded below after verification.

Music DNA409 source tracing reaches capture_refresh_guard.valid() checks before
and after profile/provider awaits. Relevant predicates cover exact record/manager,
consent/generation, Profile/backend/account/runtime identity, paired entry/provider
registration, privacy and authority. Existing installed diagnostics identify the
error code but not which predicate failed. This read-only source trace does not
establish a production root cause or justify disabling those checks.

## Build40060 verification and requested device installation

Owner explicitly expanded the earlier installation pause to the four named
devices. No CI run, push, protected merge, HA/Pi update, pairing change or other
installation was performed. Existing Mac app bundles were retained as backups;
no UserDefaults, app container, token or Profile was reset.

- Full Swift suite:550 tests PASS32.835s,
  `/private/tmp/djc-40060-final-tests.log`.
- Signed iOS generic/physical-device build: BUILD SUCCEEDED,
  `/private/tmp/djc-40060-ios-signed.log`.
- Signed macOS build-for-testing: TEST BUILD SUCCEEDED,
  `/private/tmp/djc-40060-mac-signed.log`. Native XCTest execution is not claimed.
- Localization:1123keys/five languages PASS; git diff --check PASS.
- Exact iOS executable SHA256:
  `33295c7c7b34707b6e24eb4d4d4dec7f12c0479beabc7f6150c41ed7f1c32dd9`.
- Exact Mac executable SHA256:
  `1a22cebb7b1e877595880f3c136b1fcaa4a1ecffdb841de10b53282a9af1c839`.

| Device | Fresh pre-install read | Installed readback | Launch |
| --- | --- | --- | --- |
| Peter-iPadPro |40021|4.0.0/40060|devicectl success|
| Peter-iPhone17Pro |40059|4.0.0/40060|devicectl success|
| MacBook mbpro-peter |40059|4.0.0/40060 + exact Mac SHA|new ordinary process confirmed|
| Mac mini macmini-m6 |40058|4.0.0/40060 + exact Mac SHA|new ordinary process confirmed|

The fresh pre-install reads supersede older assumed installed-version statements.
Build40060 avoids reusing40059 already found on the iPhone and MacBook. Device
receipts are `/private/tmp/djc-{ipad,iphone}-40060-{install,after-app,launch}.json`;
Mac mini receipt `/private/tmp/djc-macmini-40060-install-receipt.json`; MacBook
receipt `/private/tmp/djc-macbook-40060-install-receipt.json` is on the MacBook.

The late missing-optional-live-capability regression was first reproduced with a
delayed capability reply after a successful authenticated HTTP detail. Production
paired transport now keeps that HTTP snapshot and its original expiry, instead
of clearing it solely because an optional WebSocket route is absent. Explicit
legacy/test auth without HTTP recovery retains its unavailable-state behavior.
Actual HTTP401/Profile refusal still withdraws private owner state.

Final native40060 confirmation used the same isolated bundle/loopback fixture.
AX checked exactly one status button on each of the eight requested live pages
and zero on Earlier Sessions. The popover shows Verbonden · lokaal and no
contradictory Gekoppeld/dot. Credit detail AX shows the exact verified context,
MusicBrainz · CC0-1.0 and no serialized dictionary. Screenshots were inspected.
Receipts: /private/tmp/djc-40060-native-page-receipt.json,
/private/tmp/djc-40060-native-{connection-popover,credit-detail}.{txt,png}.
All157 current Sources/Tests/Apps files match the build input byte-for-byte;
hashes are in /private/tmp/djc-40060-source-manifest.json. The temporary app and
fixture were stopped. These native fixture results are not live provider or
whole-list end-user acceptance.

## Follow-up: Track Insight refresh at the far right

Owner screenshot requested refresh after the connection indicator. The iOS/iPadOS
trailing group now orders optional share, connection, refresh. macOS keeps share
in navigation and orders connection, refresh at the trailing edge. Explicit
Moment detail keeps its own retry at that edge without another connection icon.
Unsigned iOS and Mac compile checks passed with local build number40061:
/private/tmp/djc-refresh-right-{ios,mac}.log. No additional installation was made;
the four installed apps remain40060. This presentation-only edit did not rerun
the full550-test suite; that result above belongs to the40060 source checkpoint.

Ask DJ follow-up: the same far-right refresh rule now orders trash, connection,
refresh on iOS/iPadOS and macOS, while search remains at the navigation edge.
The existing refresh action/disabled/accessibility behavior is reused by both
platforms. Both unsigned builds pass in /private/tmp/djc-askdj-refresh-right-{ios,mac}.log.
No further installation; this joins the pending40061 presentation changes.

Legal page follow-up: Juridisch and OSS are now independent glass cards using
shared24-point section spacing and padding. Both section dividers are disabled;
the localized legal text is unchanged. Both unsigned builds pass in
/private/tmp/djc-legal-cards-{ios,mac}.log. Pending40061 presentation change only;
no new installation or full regression rerun for this layout-only edit.

Splash follow-up: the icon, DJConnect wordmark and slogan now share the standard
glass-card surface. The old opaque branding gradient and dark multiply overlays
are removed, while the existing layout, hero and startup timing stay intact.
The shared surface supplies its normal border and Reduce Transparency fallback.
Both unsigned builds pass in /private/tmp/djc-splash-glass-{ios,mac}.log.
Pending40061 presentation change only; no further installation.

Discover clipping follow-up: restored the horizontal ScrollView's normal clip
and explicitly clipped each padded section to the shared rounded card shape
before applying its glass/border. Covers and text cannot paint outside the card;
the same fix covers Rediscover and Artists to explore. Both unsigned builds pass
in /private/tmp/djc-discover-clipping-{ios,mac}.log. Pending40061 presentation
change only; no further installation or full regression rerun for this layout edit.

## Track Insight automatic analysis on screen entry

Opening ordinary Track Insight now requests the playing track through the
existing service, without force_refresh or another navigation request. If status
arrives after opening, the visible screen starts once playback is available.
Existing matching analysis is reused, concurrent loading is guarded, and view
redraws do not trigger another request. No playback/paused state starts no work;
a failure remains visible with manual retry, without an automatic retry loop.
The explicit Moment detail is excluded and remains pinned to its own subject.
Automatic completion is fenced to the original playback/context/language/owner
epoch and foreground lifetime. Late/cancelled results cannot populate current
analysis, history or widgets after that context is gone.

Seven new source scenarios cover playing/current reuse/in-flight overlap,
paused/empty/failure and track change/background/cancellation. Full Swift suite:
552 tests PASS29.740s in /private/tmp/djc-insight-auto-open-full-tests.log.
Both unsigned builds PASS in /private/tmp/djc-insight-auto-open-{ios,mac}.log;
1123 localization keys/five languages PASS; git diff --check PASS. This joins the
pending40061 changes and has not been installed on the four40060 devices.

## Mood marker vertical jump follow-up

The earlier horizontal-offset animation did not stabilize its parent popover.
Mood changes inserted a progress row while awaiting confirmation and removed it
afterwards, changing the anchored popover height. The status row now retains
its layout space when idle (hidden visually and from accessibility); progress,
errors and unavailable status share that slot. The header SF Symbol also has a
fixed 24-point box so different symbol heights cannot shift the slider below.
Marker travel remains the existing horizontal-only offset animation with Reduce
Motion support. No backend selection or confirmation behavior changed.
Unsigned Mac and iOS builds PASS: /private/tmp/djc-mood-stable-{mac,ios}.log.
Localization validation PASS (1123 keys); git diff --check PASS. Source/layout
validation only: actual popover motion on installed hardware is not yet verified.
Pending40061; these changes have not been installed over40060.

## Track Insight mood toolbar and standalone color choice

Ordinary Track Insight now offers the shared mood popover before connection
status and refresh in the iOS/iPadOS and Mac toolbar. With an active Session it
uses ActiveSessionMoodToolbar and its existing confirmed backend operation.
Without a Session, a view-local visual choice drives the hero, metric palette
and share preview. This ephemeral choice does not write a Profile, create a
Session, alter analysis inputs or reuse the old Ask DJ preference. Pinned Moment
details do not offer this selector. Refresh remains at the trailing edge.
Unsigned Mac/iOS builds PASS: /private/tmp/djc-insight-mood-{mac,ios}.log.
Full Swift regression suite: 552 tests PASS in 29.506s,
/private/tmp/djc-insight-mood-tests.log. Localization validation PASS (1123 keys);
git diff --check PASS. Pending40061, not installed; physical UI acceptance open.

## Remove Track Insight private rendering label

Removed the entire TrackInsightPrivacyFooter (lock icon, localized text and
its layout space) from ordinary and pinned Track Insight. This is a presentation
removal; missing qualified analysis remains an open diagnosis, not resolved by
removing the footer. Pending40061; not installed. Validation recorded below.
Unsigned Mac/iOS builds PASS: /private/tmp/djc-insight-footer-{mac,ios}.log.
git diff --check PASS; no full regression rerun for this label-only removal.

## iPad floating Ask DJ composer

Removed the phone-only restriction from the iOS floating composer in both
active DJ Session and Ask DJ. The existing rounded material input now overlays
the bottom of the scroll surface on iPad too, with horizontal/bottom spacing
and a centered content-width limit (1000 points on Session). Measured composer
height still reserves scroll space and lifts the scroll-to-top control. Search
hides the composer, archived Sessions remain without an active composer, and
Mac retains its existing docked layout. Pending40061, not installed; physical
iPad portrait/landscape/keyboard acceptance remains open.
Unsigned iOS/Mac builds PASS: /private/tmp/djc-ipad-floating-{ios,mac}.log.
git diff --check PASS; no full regression rerun for this layout-only change.

## More page glass navigation cards

Replaced the single opaque gradient list and row separators with individual
24-point rounded shared glass surfaces. Rows have 44-point purple icon badges,
semibold white wrapping titles and a visible chevron; Feedback uses the same
component. An adaptive grid (280-point minimum, 12-point gaps, 1000-point content
limit) gives phone-width single-column rows and multiple columns on larger
iPad windows. Existing destinations and feedback sheet actions are preserved.
The shared surface supplies native glass/material and Reduce Transparency
behavior. Unsigned iOS/Mac builds PASS in /private/tmp/djc-more-glass-{ios,mac}.log.
Localization validation PASS (1123 keys); git diff --check PASS. Layout-only
change, no full regression rerun. Pending40061; no installation or physical
visual acceptance claimed.

## iPad Session title and clear recovery action

The DJ Session navigation title is now empty on both iPhone and iPad; Mac
retains its title. Session-history unavailable and timeline-error panels now
show an explicit arrow.clockwise + Refresh page button using the primary
white-on-gradient style, avoiding the nested secondary live-glass background.
The unavailable message no longer ends in a vague Try again instruction; Dutch
now reads De sessiegeschiedenis is tijdelijk niet beschikbaar. All five
localizations include the explicit action label (Ververs pagina in Dutch).
Recovery operations and authority checks remain unchanged; backend history
unavailability itself is not declared solved by this presentation change.
Unsigned iOS/Mac builds PASS: /private/tmp/djc-ipad-session-refresh-{ios,mac}.log.
Localization validation PASS (1124 keys); git diff --check PASS. Pending40061,
not installed; physical iPad readability acceptance remains open.

## iPad HTTP500 diagnosis — actual device and running HA

Read only the iPad app diagnostic file (500 retained lines). It contains414
HTTP500 failures on POST /api/djconnect/v1/command, including manual refresh and
ongoing status polls. No extra API requests were made. The physical HAOS host
log was checked first but had no matching traceback; the local homeassistant
container supplied13 repeated matching tracebacks in its bounded recent tail.
Device authentication succeeds before the fault. Installed api_handlers.py:802
calls _debug_playback_request; line2214 calls music_backend_metadata(None,runtime).
That reaches use_cases.py:642/610 and profile_backend.py:242, which raises
ProfileStorageValidationError(profile_connection_unavailable) with no HA storage
context. Debug logging therefore raises before normal command dispatch. This
does not establish a bad persisted Profile mapping. Five other debug helper
metadata calls in the installed file also pass None and require Core review.
Running source was copied read-only and SHA256-bound in the redacted receipt:
/private/tmp/djc-ipad-http500-diagnosis-20261015.json. Raw logs remain temporary
local diagnostics, are not committed, and have not been sent externally.
Now Playing command/status cause is confirmed; the retained iPad log has no
direct Track Insight endpoint failure, so its independent cause stays open.
No re-pair, profile mutation, backend source edit, log-level change, deployment
or restart. User permits iPad takeover today, but CUA failed initialization
twice; no UI-control or native acceptance claimed. Core writer handoff awaits
explicit messaging authorization. This diagnosis does not fix the running HA.

## Remove New contributions button from DJ Session

Removed the composer banner button and its unused new-entry tracking state
from SessionTimelineScreen. Both floating iPhone/iPad and docked Mac composers
now contain only AskDJInputBar. Timeline delivery, existing scroll-to-current
button and reading/search position handling are unchanged. Pending40061, not
installed. This is a layout-only removal; no full regression rerun.
Unsigned iOS/Mac builds PASS: /private/tmp/djc-remove-new-contributions-{ios,mac}.log.
git diff --check PASS.

## Premium Mac launch layout

Mac launch now uses a centered desktop composition at window widths >=880: a
400-point shared glass icon/wordmark/slogan banner and version/loading column
beside the 340-point Session hero on the shared blue/purple launch canvas.
Narrow Mac windows retain the compact vertical layout used on iPhone/iPad.
Startup bounds and transition behavior remain unchanged. Unsigned Mac/iOS
builds PASS in /private/tmp/djc-mac-premium-launch-{mac,ios}.log. Actual native
wide-Mac screenshot captured and visually inspected: banner, text, artwork and
status fit cleanly. Isolated ad-hoc demo bundle dev.djconnect.mac.launchproof,
not the installed personal app; probe stopped afterwards. Receipt:
/private/tmp/djc-mac-premium-launch-receipt.json. Pending40061; no installation.

## Apple transport queue readback and Pi10 initial diagnosis

Fresh Apple #87 readback (222 comments) confirms selected dependent workpackage
DJC-APPLE-HYBRID-TRANSPORT-ADOPTION-V1-20261013, comment6149955349. Follow the
current bugs/corrective work using the same writer and route coordinator. The
latest producer comment6185756317 is still an EARLY local/unpublished pin
2c3734d0d336d64a125eeb35dfe7fade69e28126, not final consumer admission.
Required consumer work: automatic trusted-local WS for Broadcast/supported
actions; appropriate local HTTP fallback; external HTTPS/HTTP recovery away
from home; automatic qualified LAN return. Remove normal-use WebSocket toggle
and migrate old overrides. Validate endpoint/installation TLS identity before
token release (foreign Wi-Fi is not home LAN). One demultiplexed receive loop,
request/connection IDs, bounded pending/cancellation/late-response cleanup.
Use original UUIDv7 operation_id and boot operation_epoch across routes,
status reconciliation for uncertain sends, immutable 300-second lifetime and
compact receipts; never blindly replay potentially executed mutations. New
paired action audience paired_owner_actions and /api/djconnect/v1/actions/paired;
Broadcast remains subscribe/recover-only, no /websocket/session issuer.
Bounded liveness/lease/recovery distinguishes quiet playback from dead sockets
and withdrawal from transport failure; coalesce probes and measure load/latency.
Same DTO/authority/revision/source-expiry fences on HTTP and events; preserve
Session, selected subject, draft, choices and scroll without resurrecting data.
Qualify all feature categories and real Mac/iPhone/iPad LAN-cellular-LAN, foreign
Wi-Fi, foreground, lease/restart and configuration-recovery transitions. Pin
final Core schema/fixtures/artifact and compatibility before adoption; follow
normal reviews/protected delivery/Finalization and existing installation gates.
Lane links:
https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6149955349
https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6185756317
No transport source adoption was started by this readback.

Pi10 fresh read-only diagnosis: SSH alias djconnect-pi10 resolves to
rbpi5-djconnect. Ordinary djconnect-client/api services active; actual
djconnect-wall-kiosk and djconnect-wall-x11vnc both inactive/dead/MainPID0.
Touch-app screenshot and actual DISPLAY=:0 root screenshot are both black.
Prior Pi thread confirms the receiver had been started temporarily, with the
ordinary touch client returning after reboot. No inference that a reboot was
observed; only present service/screen state is proven. Request to reopen the
existing kiosk services for E2E is pending; no service changes, update, pairing
or reboot performed. Screenshots retained temporarily, not committed.

## Authorized Pi receiver activation, HA-dev alignment and waiting-page preview

Owner approved reopening the existing Pi10 kiosk, then explicitly requested the
Mac mini HA-dev URL. Stopped only ordinary touch/watchdog/touch-VNC and started
the existing wall-kiosk/wall-x11vnc. Changed only RECEIVER_URL in the Pi startup
script to the Apple app's configured HTTPS HA-dev origin, retaining backup
/usr/local/bin/djconnect-wall-kiosk.before-ha-dev-20261015-101634. Receiver and
VNC restarted and actual Pi screen now shows waiting state and a fresh code.
The public HTTPS tunnel was read-only verified to target local127.0.0.1:8123,
while the old Pi origin was physical HA192.168.1.13. No pairing was changed.

Owner separately requested a djconnect branch and only HTML publication to
HA-dev. Isolated Core worktree:/private/tmp/djc-vibecast-waiting/source, branch
codex/vibecast-waiting-glass-v1, source723ba0438b6b999bd4eed6f3a1dba923b3c78b76
on main9efd1977; documentary readback74fe5078. Existing Core Hybrid writer/WIP
was preserved. Shared sources generate branded glass idle page with three
localized instructions, the VibeCast monitor/Wi-Fi icon and code.11 tests PASS;
only vibecast.html changed in HA-dev,156 other integration files hash-equal,
no HA restart. Actual physical Pi waiting-page screenshot visually inspected.
Owning report: docs/verification/VIBECAST_WAITING_GLASS_HA_DEV_20261015.md in
that isolated Core worktree. No push/merge or production HA publication.

Owner requests actual iPad-to-Pi Session/Mood/Presence E2E and permits Spotify
playback on the Mac mini built-in speaker. A separately signed standalone UI
test helper was built and installed; it references the existing DJConnect
bundle without compiling/installing/resetting the main app. Runner launched
but failed enabling automation mode (60-second timeout); CUA also fails startup.
No iPad UI action, Session handoff, Mood/Presence mutation or Spotify/output
command has therefore been tested; those cases remain OPEN, not fixture PASS.
Read-only installed renderer inspection shows album-art tones override the mood
palette while artwork is present; actual live mood transition is NOT_RUN.

Accumulated Apple40061 local regression suite552 PASS29.595s in
/private/tmp/djc-40061-consolidated-tests.log. No new Apple installation.

## Hybrid detailed Apple handoff reconciled

Read the newer Core→Apple handoff6186713492, which supersedes the coarse early
checkpoint details but still explicitly lacks a final qualified producer pin.
Prepared HYBRID_TRANSPORT_APPLE_ADOPTION_V1.md with current-source gaps, bounded
implementation order and separate Core/Swift/native/installed/joint acceptance.
Existing route/replay/context fixes are preserved; no legacy toggle activation,
new paired-action Swift implementation or mutable Core schema adoption yet.
The setting/legacy issuer will be retired as part of actual automatic adoption,
not represented as already implemented. No external ACK/comment was posted.

## Integral Apple push repair: verified local build40061, live delivery open

Fresh read-only installed Mac mini diagnosis found push_registered=false and
last_push_error=trusted_issuer_not_configured. Its installed bundle lacked
DJConnectTrustedPairingIssuerBaseURL. Both native app Info.plists and project.yml
now ship the canonical public https://api.djconnect.dev issuer already documented
by Core/API; no embedded credentials or backend contract changes were introduced.
The relay public health check returned HTTP200; this is reachability only.

Both delegates now retain early APNs token/error callbacks and compact recognized
event metadata in a bounded RAM-only startup buffer. Cold discovery taps retain
Discover routing instead of falling through to Ask DJ. Known Ask DJ events refresh
canonical history and taps open Ask DJ; unknown events do not fetch private history.
Notification prose is never cached or treated as authoritative personal content.

Registration, bootstrap and retry continuations check current pairing, HA route,
token/signature and owner-response epoch before applying status or reporting errors.
Regression tests exposed an additional premature mutation inside the registration
logging function; logging is now observational only, so obsolete replies cannot
bypass the guards. Existing explicit server-confirmation/environment checks remain.

Validation:558 Swift tests PASS29.621s, including six new configuration/startup/
routing/late-response regressions. Localization1124keys/five languages PASS and
git diff --check PASS. Final unsigned and existing-identity signed iOS/macOS builds
both BUILD SUCCEEDED. Deep strict signature verification and packaged entitlements
PASS:both carry development APNs entitlement and the canonical issuer URL.
Evidence:/private/tmp/djc-push-integral-{tests,ios,mac,ios-signed,mac-signed}.log,
/private/tmp/djc-push-integral-artifact-receipt.json. Unsandboxed codesign verified
entitlements after the sandboxed inspector could not read the entitlement blob.

iOS executable SHA256:283d7ed61bab6d6291aeaa3d3f8f6e25003d0913f6408f60cd42d4115fe11409.
Mac executable SHA256:ff381b9f6e694f85483a7f8ccd5fdff4a0ffc23f735aeb16c0baf3d26f954649.
No new app installation, authenticated issuer/registration request, test push,
CI, push or merge performed. Existing ordinary apps remain40060. Actual server
registration, APNs sandbox receipt in foreground/background/cold start, tap routing
and production/TestFlight environment delivery remain OPEN; source and signing
validation do not close those acceptance boundaries. Retained delivery/installation
gates still apply after the earlier explicitly requested40060 installations.

## Authorized40061 installation and real Pi session screenshots

Owner explicitly lifted the installation/testpush pause. Build40061 installed and
launched on iPad, MacBook and Mac mini with data/pairing retained; strict signature
and exact-file verification PASS on both Macs, backups retained. Prior Mac build
included XCTest-only absolute-read/mach-lookup exceptions;40061 removes only those,
all other entitlements equal. Mac mini installer initially stopped before mutation
because its process-name guard saw the separate launchscreen proof app. Replaced
that check with exact installed executable path and completed safely; proof app
was not terminated. iPhone installation failed CoreDevice4016 unavailable; not
installed or claimed current.

Actual Mac mini Session started through native app. Physical Pi code approved
through native VibeCast UI; Pi changed to LIVE. Selected macmini-m6 via the real
output picker; system audio readback identifies built-in Mac mini speaker as
default output. Spotify playback/metadata reached Pi, with Editors album artwork
and matching gold/brown palette. Physical screenshots:
/private/tmp/djc-40061-screenshots/pi10-wachtscherm.png and
/private/tmp/djc-40061-screenshots/pi10-actieve-sessie.png.
This proves real Mac-to-Pi handoff/rendering, not iPad-origin handoff or Mood/
Presence acceptance. The iPad autonomously discovered the Session but a retained
possible-crash report sheet obscures its UI. Direct devicectl screenshot works;
CUA still fails trusted Node startup. Asked owner to dismiss sheet for clean iPad
capture; no fake/simulator/cropped replacement screenshot supplied.

Live push40061:Mac APNs callbacks return tokens, but server registration has not
completed; iPad reports permission_granted=false and does not start registration.
No APNs delivery PASS. Source regression additionally reproduces a startup-owner
response-epoch change discarding registration without resuming. Follow-up permits
one foreground retry in current context only when identity/token/route remain
unchanged, with no background retry or unbounded retry loop.560 tests PASS30.086s
including recovery/background/bounded-repeat checks. One earlier parallel run had
an unrelated timing failure in VibeCast successor-session refresh; final full
rerun passed. Final log:/private/tmp/djc-push-owner-transition-tests-final.log.

## Live push bootstrap succeeded; authentication boundary remains open

Further installed evidence corrects the earlier bootstrap-only uncertainty:
HA-dev logs11:45:46 show the native retry including bootstrap_proof_present=True;
11:45:47.090 central install-token bootstrap succeeded, HTTP200, token received.
The same window contains46 successful device-token equality checks for the Mac
mini before the app reports auth stale HTTP401 at11:45:47 and invokes existing
pairing-withdrawal behavior. HA service registration repeats immediately after
central token persistence. Runtime reload/in-flight-request interaction is a
candidate, not a proven root cause. No invalid bearer token was established.
MacBook40062 also reached the native re-pairing-required presentation. No manual
re-pair, Profile change, credential restoration, Core edit/deploy/restart or
security-bypass retry was performed. Do not call registration or APNs receipt PASS.
Redacted evidence:/private/tmp/djc-push-live-auth-boundary-20261015.json. Raw local
window retained privately; no tokens copied to reports. Asked owner permission to
send this bounded finding to the existing Core writer; not sent without approval.

Shared bootstrap helper now accepts its caller's context validator. The iOS Watch
proxy validates its own pairing/route/owner epoch instead of incorrectly depending
on a simultaneous phone APNs request.560 tests PASS29.977s; signed iOS (including
Watch proxy compile path) and macOS40063 BUILD SUCCEEDED, strict/deep signatures
verified. No physical Watch push acceptance is claimed.

Latest installed:Mac mini40063 and iPad40063 (opened, existing state retained);
MacBook40062, because normal quit is blocked/cancelled during its changed setup
presentation. Installer stops before bundle replacement; no force-quit fallback.
iPhone remains previous40060, CoreDevice4016 unavailable.40063 signed artifacts
and hashes:/private/tmp/djc-push-40063-artifacts.json. Installation backups retained.

Physical requested screenshots delivered as local links:Pi idle and active with
Editors track metadata/artwork; latest iPad actual active Session/playback and
DJ contributions, but still obscured by the possible-crash sheet. No crop/mock
replacement supplied. iPad auto-discovery and floating composer are visible behind
the sheet. Owner can dismiss Niet nu for a clean screenshot; native screen capture
works, UI automation does not. Screenshots:/private/tmp/djc-40061-screenshots/.
Temporary unified log stream stopped. No testpush sent before confirmed registration.

## Branding follow-up: build40065

The crash prompt used a separate AboutBanner layout with the bare app-icon image.
AboutBanner now delegates to the same DJConnectLaunchBanner used by the launch
screen. Its shared icon has an inset glass tile, specular highlight and beveled
outline; the recognizable brand artwork is retained. Other sheets and About
inherit the same treatment. Native signed Mac and iOS build40065 PASS. This is
appearance-only and does not claim to fix the separate crash-notice cause.

Physical iPad build40065 installed and launched. Screenshot
/private/tmp/djc-glass-brand-ipad-40065.png visually confirms the shared banner
and inset beveled glass logo in the actual crash prompt, with readable title and
subtitle. The prompt remains present; no upload or pairing change was performed.
Mac build40065 is signed/build-verified, not installed in this follow-up.

## Integral logo/modal audit: build40066

Source inventory of every DJConnect logo reference found16 AboutBanner users:
all route through the shared glass launch banner. The remaining bare logo in the
demo album placeholder and three Watch locations (pairing, Welcome sheet, About)
now use their shared glass-logo wrappers. The phone/tablet/Mac bare asset loader
is private, so another screen cannot accidentally bypass its wrapper.

Native signed Mac and iOS builds40066 PASS, including Watch compilation/signing.
Logs: /private/tmp/djc-brand-audit-mac-final.log and
/private/tmp/djc-brand-audit-ios-watch-final.log. Source audit and scope inventory:
APPLE_BRANDING_SURFACE_AUDIT_20261015.md. No claim of physical Watch acceptance or
opening every modal on hardware. This build is not installed in this follow-up;
physical iPad remains on visually checked40065 and Mac mini on40064.

## iPad floating Ask DJ width: build40067

Owner requested25% narrower. Both Session and Ask DJ now use a shared iPad-only
container-relative width of75% of their former capped available width, centered.
Text size, microphone/send touch targets and height are unchanged. The calculation
uses the actual container width for portrait/Split View; no screen-bound constant.
Native signed iOS and Mac builds40067 PASS. Installed and launched on the physical
iPad. Screenshot /private/tmp/djc-ipad-composer-75-40067.png visually confirms the
Session composer is narrower and centered (visible behind the existing crash
sheet). Typing/keyboard, rotation, Split View and the separate Ask DJ page were
not physically exercised in this change. Mac/iPhone width behavior is unchanged.

## Push false401/root-cause correction: build40068

Reproduced Core push-persistence → runtime replacement → pairing_revoked → Apple
syntheticHTTP401 → credential deletion. Both implicated installed HA-dev source
functions match the investigated code. Detailed causal evidence and limitations:
PUSH_BOOTSTRAP_RUNTIME_RELOAD_ROOT_CAUSE_20261015.md.

Apple now withdraws private state immediately but independently validates the
paired identity before deleting a credential. Temporary503, unqualified proxy401,
changed token/configuration and background cancellation are covered. Push failures
also clear old green registration confirmation.580 Swift tests PASS; signed Mac
and iOS builds PASS. Ordinary Mac mini and physical iPad installed40068.

OPEN: Core writer companion fix (messaging permission pending), MacBook/iPhone
installation, and real APNs registration/delivery. Existing Mac mini was already
unpaired; no token restoration, re-pair, Core source mutation or HA restart here.

## Physical iPad WSS E2E request — preflight only

Fresh route readback shows all three configured URLs use the public ngrok origin.
The installed Hybrid implementation therefore uses external HTTPS for actions;
local action WSS is not admitted for this hostname. Screenshot/log access works,
but CUA initialization fails and one fresh physical XCTest attempt timed out
while enabling automation. Actual all-screen/all-flow E2E remains NOT RUN.
Matrix and exact evidence: IPAD_WEBSOCKET_E2E_20261015.md. Owner question for an
existing trusted local HTTPS HA-dev address is pending. No TLS bypass, re-pair,
server change or fake native PASS was introduced.


## Ask DJ keyboard / glass selector slice — build40070

Owner's newest refinement supersedes the intermediate Presence slider requests:
Mood and Presence both use shared segmented glass choice buttons, selected purple
and one selected label beneath. Mood uses four options; Presence five. Session
Mood and standalone Track Insight share the same renderer. Removed the duplicate
Presence pending/selected footer and spinner. Original capability-loading/error
and conflict handling remain; backend confirmation is not replaced with a local
success claim. The selected-contribution close button uses shared press feedback.

Keyboard first attempt49f602e was reproduced failing in both simulator cases.
76ab190 fixes native UIKit responder dismissal rather than relying on unbound
SwiftUI FocusState. Both Session and Ask DJ outside taps now PASS in native
isolated iPad simulator: keyboard closes, draft retained, inside tap does not
close it, editing resumes. Exact final UI rerun:2 tests PASS, log
/private/tmp/djc-askdj-glass-final.log, resultbundle same stem.xcresult.

New glass mood test initially failed because the simulator could not launch the
app. After restarting only the isolated simulator, test-without-building PASS:
four accessible44pt choices, selected Feest confirmation and actual screenshot
exported/visually inspected. /private/tmp/djc-mood-glass-retry.xcresult;
/private/tmp/djc-mood-glass-retry-attachments/391D8CD1-B4DC-462C-9FED-C632A17E34F1.png.
These are demo-native visual/input proofs, not live backend or physical-iPad
interaction acceptance. No separate live Presence click/confirmation proof.

Signed native Mac and iOS40070 builds PASS. Physical iPad install/launch PASS;
actual post-launch screenshot shows real current Session and same glass composer,
with the existing possible-crash prompt still covering it. No assertion that the
agent dismissed or tapped that physical UI. Device automation remains unavailable.
Buildinput source equals bounded UIcommit76ab190; source publication remains
paused. Mac mini install receipt is recorded in the closure note. MacBook/iPhone
have not been updated during this increment.

Next selected independently actionable lane increment started by the same writer:
DJC-APPLE-SESSION-MOMENT-ARTWORK-V1-20261014, Corepin5c7ecb79. cfebbde commits
exact imported transport fixtures, shared decoder/admission boundary and5 passing
tests. See APPLE_SESSION_ARTWORK_ADOPTION_20261015.md. Full loader/card/native and
joint acceptance remainOPEN. Hybrid physical E2E remains explicitlyOPEN; this
continuation does not silently qualify it. Speech/Persona remains after artwork.

Final installed Mac mini readback: ordinary/Applications/DJConnect.app40070,
PID94954, strict/deep signaturePASS, exact installed files, entitlements and
preferences preserved. Receipt/private/tmp/djc-ux-40070-mac-install.json;
backup in Application Support/DJConnect/InstallBackups/40070-askdj-glass-final-20261015.
Normal quit was first blocked by crash/setup sheets; closed only “Niet nu” and
then the app's own “App afsluiten”, without upload, credential edits or forced
termination. The app remains unpaired as before. Physical iPad40070 install
receipt/private/tmp/djc-ux-40070-ipad-install.log; launch and actual screenshot
/private/tmp/djc-ux-40070-ipad-ready.png. Implementation/build/install delivered;
physical interaction and live Presence confirmation remain unqualified.


## DJ-session playback album art +50% — build40071

Owner's requested size increase is isolated in38e9d40. Artwork maximum180→270pt;
side-by-side column min(180,width*.25)→min(270,width*.375), so both capped and
width-constrained layouts grow by exactly1.5. Phone stacked layout remains
container-bounded; uncropped scaledToFit and glass wrapper are unchanged.
Signed native iOS and Mac builds PASS. Physical iPad installation PASS
(/private/tmp/djc-artsize-40071-ipad-install.log); Mac mini ordinary app40071
installed and launched, strict/deep signature and exact files PASS, entitlements
and preferences preserved (/private/tmp/djc-artsize-40071-mac-install.json).
No new low-impact layout tests; physical visual interaction remains unqualified.
MacBook/iPhone have not been updated during this increment. Source publication
pause preserved; artwork adoption continues separately from this size adjustment.
