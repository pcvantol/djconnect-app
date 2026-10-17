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
