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
