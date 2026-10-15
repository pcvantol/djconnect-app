# Apple feedback: current disposition — 2026-10-15

This is the current view of the owner's complete feedback list and Apple lane #87.
It supersedes the intermediate counts and candidate pins in
[the chronological worklist](APPLE_FEEDBACK_20261014.md). A source correction is
not an installed fix. The owner subsequently authorized installation on iPad, iPhone, MacBook and Mac mini.
All four now run build40060. CI/merge/publication, HA/Pi updates and re-pair remain
outside this authorization. Installation is not acceptance of every reported bug.

Sole writer: `build/apple-40017-recovery/source`, branch
`codex/apple-dj-presence-v1`, starting HEAD `3c89327`. Original root WIP and the
extra untracked Xcode projects are preserved. The disposable `/private/tmp`
checkout is byte-copied build input, not another source writer.

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
