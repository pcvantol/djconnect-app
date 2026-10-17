# Ask DJ history playback and neutral system launch

Owner requests: show play icons on the recently played track rows; use only the
logo and DJConnect on the initial OS launch screen, followed by the existing
localized tagline in the app.

Base: protected main f6b0a71b3d8a2076539a2aea5e853626558b04ad. Work branch:
`codex/apple-history-row-play-launch`. Not merged. Included in ordinary iPad40283 installed/read back after the clear-state correction; source98eda79. The history replay producer dependency remains open, so physical replay is not qualified.

The history row now displays a trailing44pt play control only when that same
message supplies one matching, consistently identified backend track action.
Existing message freshness/Profile/action admission and command handling remain
in force. URI-only informational rows do not create playback authority. Matching
actions render inline without duplicate action cards; artwork, played-at labels
and repeated listens are retained. Repeated URI rows use occurrence identity.

The canonical Core recently-played response currently supplies informational
items without playback_actions. That producer dependency was sent to the
existing sole Core-writer in the shared-renderer lane: supply backend-owned
replay actions/result identities with Profile/provider/target admission and
negative fixtures. No local recommendation, title search, URI-to-command
synthesis or Core source modification is part of this Apple change. Until the
producer supplies actions and the new Apple build is installed, the reported
physical screenshot is not fixed end to end.

The launch storyboard now contains only LaunchIcon and the DJConnect name.
Unused launch-specific translations and the static spinner are removed; the
five existing brand.tagline translations remain in the runtime SwiftUI launch.
The project was regenerated from project.yml. This implements the owner's
neutral-branding choice; the preserved old Base-storyboard experiment remains
outside the change. Physical iPad first-frame acceptance is not claimed.

Validation:1257localization keys/fivelanguages PASS; shared branding/neutral
launch validator PASS; ordinary installation hygiene2tests PASS; Apple ibtool
compiles the iOS launch storyboard without errors/warnings/notices. The first
Swift invocation stopped before tests because the existing SwiftBuild cache
bundle has resource-fork metadata rejected by codesign. A clean isolated native
Swift build compiled Core/UI and the targeted row-action regression passed
(1test,0.001s). The initial testfixture used an invalid role name; compilation
rejected it and the fixture was corrected to the existing dj role before PASS.
No cache metadata or signing policy was altered.

## Discover iPad portrait width — ordinary40284

The owner requested removal of the large side margins on Discover. Only its iOS
regular-width portrait container now uses the actual available width instead of
the760pt cap. The existing16pt edge inset remains. Compact layouts and the
landscape/Mac width policy retain their behavior. This is a local presentation
change with no Profile/backend model change.

Incremental signed iOS40284 build including embedded targets PASS; strict deep
signatures/ordinary-product checks PASS. iPad install, independent apps-version
readback40284 and process launch PASS. Private receipts/log:
`/private/tmp/djc-discovery-width-*`. No new physical viewport screenshot was
captured, so visual acceptance remains distinct from installation. Prior786test
result binds the preceding shared-state change; it is not a new layout test.

## Persistent centered Logs title — ordinary40285

Owner requested that Logs remains centered in the top bar when scrolling. The
iOS Logs screen now uses the native inline navigation title. Removed its custom
scroll-offset title overlay/state/geometry observer. Title visibility no longer
depends on the log scroll position; search/copy/clear actions are preserved.

Incremental signed iOS40285 build including embedded targets PASS; strict deep
signatures and ordinary-product inspection PASS. Only iPad installed, independently
read back40285 and launched. Private logs/receipts:
`/private/tmp/djc-logs-title-*`. No physical scrolled viewport was captured;
installation proof is not visual acceptance. No new test was added for this
small presentation-only change.

## Games available-space layout — ordinary40286

Owner requested larger game cards in iPad portrait/landscape while retaining
standard edge margins. Regular iOS layouts now use the container width. Canvas
height uses the remaining viewport after measured picker, card controls/help,
spacing and screen padding; removed the portrait760pt width cap and landscape
42%-height cap. The actual Canvas fills that measured rectangle instead of
letterboxing inside a fixed320:170 view. Compact/Mac aspect-fit presentation is
retained. A minimum playable height allows small viewports to scroll.

Touch positions are converted from the actual resized canvas to the existing
320x170 game coordinate space; controls and score storage keep their semantics.
The Canvas was extracted as a shared view to avoid duplicating game drawing.
Geometry state updates only when the canvas size changes.

Signed iOS40286 build including embedded targets PASS; strict deep signatures/
ordinary-product inspection PASS. Only iPad installed, independently read back
40286 and launched. Private logs/receipts: `/private/tmp/djc-games-space-*`.
Actual portrait/landscape viewport and physical touch acceptance were not
captured. No new broad Swift PASS is inferred from the preceding786test run.

## Connection popover while searching — ordinary40287

Owner reported an oversized connection popup while Queue search/keyboard was
open. Opening the shared connection toolbar action now resigns the iOS first
responder while retaining search text. Its popover fits intrinsic content height
and ignores keyboard safe-area inflation. The Session-control connection route
also presents compact content directly, bypassing the expanding menu ScrollView.
No timed presentation delay or backend/connection-state change is introduced.

Signed native iOS40287 including embedded targets PASS; strict deep signatures
and ordinary-product checks PASS. Only iPad installed/read back40287 and app
launched. Private build/install/readback logs: `/private/tmp/djc-connection-keyboard-*`.
The exact physical keyboard-open landscape viewport was not replayed/captured;
source and installation proof are not physical visual acceptance.

## Purple default switches — ordinary40288

Owner requested purple toggles, including Glass effects. The shared presentation
preference now sets an explicit purple SwitchToggleStyle, independent of parent
white tints. Glass and autoplay controls and the Mac settings container use the
same explicit style. The active track uses the existing brand-purple RGB; stored
on/off values and backend/Profile behavior are unchanged.

Signed native iOS40288 including embedded Watch targets PASS; strict deep
signatures/ordinary-product inspection PASS. Only iPad installed, independently
read back40288 and launched. Private logs/receipts: `/private/tmp/djc-purple-toggles-*`.
No physical visual toggle-state acceptance or new whole-suite PASS is inferred.

## Equal selector cells — ordinary40289

Owner requested equal option-button sizing in presence, persona and mood menus.
Their shared SessionGlassChoiceSelector now gives each symbol an identical24x28pt
intrinsic frame before its flexible48pt-high cell and shared button padding.
The HStack therefore distributes width equally without narrower glyph minima
shrinking music-note/microphone options. Existing responsive width, focus,
selection, disabled appearance and accessibility labels are retained.

Signed native iOS40289 including embedded targets PASS; strict deep signatures
and ordinary-product checks PASS. Only iPad installed/read back40289 and launched.
Private logs/receipts: `/private/tmp/djc-equal-choice-buttons-*`. Physical viewport
measurement was not captured; no new whole-suite result is inferred.

## Complete iPad session toolbar — ordinary40290

Owner requested all iPad Session actions directly in the toolbar, without More
and duplicate VibeCast/refresh entries. The existing expanded iPad toolbar now
adds DJ voice as a direct speaker button between persona and VibeCast, using the
existing epoch/session-bound voice popover and measured source anchor. More is
created only on compact/iPhone presentation. The existing capability/demo gates
for VibeCast and action guards remain. Mac toolbar behavior is unchanged.

Signed native iOS40290 including embedded targets PASS; strict deep signatures
and ordinary-product checks PASS. Only iPad installed/read back40290 and launched.
Private logs/receipts: `/private/tmp/djc-ipad-all-toolbar-*`. No physical toolbar
viewport or voice interaction acceptance was captured. Untracked duplicate
source/test/fixture/tool files appearing during work remain preserved and unstaged;
they were not regenerated into the Xcode project or included in this change.

## iPhone catch-up after vinyl-card report — ordinary40290

Owner reported the bare vinyl in DJ Session, then explicitly authorized installing
the ready40290 build on iPhone as well. Fresh preinstall app readback showed
40267. Current source already wraps both the loaded image and vinyl placeholder
in CachedArtworkImage's shared djAlbumArtworkGlassCard for Session musicContext;
no duplicate wrapper or extra source change was introduced for this report.

Reverified the existing signed ordinary40290 product supports device families
1and2 and passes strict deep signature validation. iPhone installation succeeded;
independent apps readback confirms4.0.0/40290; process launch succeeded. iPad also
remains40290. Private receipts: `/private/tmp/djc-40290-iphone-*`.
This is installed/version/launch proof, not a captured physical vinyl viewport.

## Separate iPhone connection/search group — ordinary40291

Owner requested the connection and search controls in their own leading toolbar
block on iPhone, matching iPad. The leading iOS toolbar group is now also used
for active Sessions on phone. Removed connection/search from its trailing group;
other Session controls and compact More remain. Archived-phone search placement
and existing iPad/Mac behavior are retained.

Signed native iOS40291 including embedded targets PASS; strict deep signatures
and ordinary-product checks PASS. iPhone installed/read back40291 and launched;
iPad remains40290. Private logs/receipts: `/private/tmp/djc-iphone-leading-tools-*`.
No physical narrow-width toolbar viewport was captured; installed/version proof
is not visual acceptance. No stored pairing/Profile/playback setting was changed.

## Restrained composer with Glass effects off — ordinary40293

Owner reported a very bright purple Ask DJ floating composer with Glass effects
disabled. The fallback previously overlaid the mood tint at full opacity over
the opaque material. Floating and docked composers now omit color overlays when
Glass effects is disabled or Reduce Transparency is enabled. Floating fallback
uses the existing dark opaque surface and subtle white border; glass-enabled
appearance retains its existing tint/border. Draft, focus, voice and send logic
are unchanged.

Signed native iOS40293 including embedded targets PASS; strict deep signatures
and ordinary-product checks PASS. iPhone installed/read back40293 and launched.
iPad was unavailable; owner explicitly directed: update only iPhone for now.
No further iPad attempt or MacBook update was made. Private receipts/logs:
`/private/tmp/djc-opaque-composer-*`. No actual physical glass-off viewport was
captured; prior787test proof remains bound to the preceding source9d54967.
