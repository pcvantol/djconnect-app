# Changelog

All notable changes to DJConnect App are documented here.

## 3.1.6 - 2026-06-11

### Changed

- Set app/protocol version to `3.1.6`.
- Added a one-time first-install welcome screen with a DJConnect hero and setup
  link to `pcvantol/djconnect` for Home Assistant setup.
- Added Spotify Premium requirement copy to the first-install welcome screen.
- Added a next-launch crash report prompt for suspected unclean exits, with
  redacted diagnostics copy and a prefilled GitHub issue link. The app never
  uploads logs automatically.
- Added app-side Home Assistant integration version gating: app `3.1.x`
  accepts HA `3.1.x` only (`>=3.1.0`, `<3.2.0`), shows a clear HA integration
  update message otherwise, and disables playback, output, queue, playlist,
  liked proxy, and voice controls while leaving Settings/pairing available.
- Added a Settings permissions section that shows Microphone, Speech
  Recognition, and Local Network permission state and lets users request
  Microphone/Speech permissions before using voice or wakeword flows.
- Documented the app permission inventory, module-boundary rationale, and the
  release cleanup helper.
- Updated README, handoff, sync prompts, release notes, and architecture docs
  for onboarding, Spotify Premium, crash reporting, version gating, and current
  live-validation expectations.

## 3.1.4 - 2026-06-11

### Changed

- Set app/protocol version to `3.1.4`.
- Added an initial `DJConnectIOSUITests` target with deterministic
  `--uitesting` launch mode, isolated defaults, in-memory token storage, mock
  Home Assistant URL seeding, and coverage for primary iOS navigation and
  Settings URL wiring.
- Added iOS release/signing documentation covering Apple Developer Program
  requirements, bundle identifiers, signing team setup, device testing,
  archives, and TestFlight upload prerequisites.
- Persisted Speech Recognition usage descriptions in `project.yml` so
  wakeword permissions survive Xcode project regeneration.
- Increased the default and minimum macOS main window size so the sidebar/menu
  layout has more room by default.
- Aligned iOS/macOS app-client pairing, status, command, and voice requests
  with the Home Assistant contract by using `device_id` as the only over-the-
  wire app identity and removing `client_id` headers/payload fields.
- Persisted `ha_local_url` and language metadata returned by pairing; status now
  reports local HA URL metadata and
  the reachable local app API URL.
- Local `/api/device/pair` now accepts HA app-client callbacks with
  `assist_pipeline_id` and returns `device_id`, `client_type`, and `paired`.
- Status, command, and voice requests now always use the local Home Assistant
  URL; cloud URLs are kept out of app-to-HA runtime traffic.
- Expanded macOS functional parity with iOS by adding refresh behavior and HA
  URL visibility in shared settings.
- Fixed macOS/iOS pairing polling so a Home Assistant HTTP 401 code mismatch
  stops the wait loop and tells the user to re-enter the visible app code.
- Added a local Bonjour-advertised `/api/device/*` Web API for HA -> Apple app
  traffic, including info, pairing-info, pair, command, DJ response, and forget.
- Local API now prefers a reachable LAN IPv4 URL over a best-effort `.local`
  hostname so Home Assistant can call the app directly.
- Local pairing-info now returns typed JSON and local pair failures are logged
  with the exact reject reason for Home Assistant repair diagnostics.
- macOS now explicitly declares the bundled `AppIcon` so the Dock and
  LaunchServices use the DJConnect icon reliably.
- Pairing code, local API URL, diagnostics, and long IDs/URLs are selectable or
  copyable from the native settings UI on iOS and macOS.
- Reworked Settings into a cleaner native layout with stable label columns,
  grouped actions, and less visual overlap on macOS.
- Server error response bodies are now included in diagnostics after redacting
  tokens/secrets, making HA entity/status failures easier to debug.
- Added a branded iOS launch storyboard and a shared iOS/macOS launch splash
  inspired by the DJConnect app icon.
- Added a native About screen with the DJConnect icon, app version, client type,
  platform, device identity, pairing state, and copyable local connection
  details.
- Made iPadOS support explicit in the project template so the iOS target remains
  universal for iPhone and iPad after project regeneration.
- Improved the iPad launch experience with a full-screen DJConnect hero layout
  and a dedicated launch image asset instead of relying on the app icon catalog
  entry at launch time.
- Reviewed visible shared UI labels and tightened Dutch translations for
  output, playlist, voice, pairing, reset, and diagnostics text.
- Replaced the repeat segmented text control with a single three-state icon
  button for off, track, and context repeat modes.
- Kept the shuffle icon visually inactive when shuffle is off instead of
  showing the accent color for both states.
- Moved output selection from Queue to Now Playing and kept output selection
  optimistic until Home Assistant confirms the new active output.
- Renamed the visible playback output label to output device/Uitvoerapparaat.
- Cleared playback, output devices, queue, playlists, and DJ response state
  when pairing is reset, and disabled playback controls while unpaired.
- Refreshed Now Playing and backend collections automatically on startup and
  whenever Home Assistant completes pairing.
- Loaded Now Playing through the backend `status` command before falling back
  to the lightweight status endpoint, preventing manual refresh from clearing
  album art when the status payload is sparse.
- Updated queue decoding to the Home Assistant `queue.items` contract, storing
  `queue.context` and accepting album-art aliases including `media_image_url`,
  `image_url`, and `entity_picture`.
- Kept the Client API url stable after successful local pairing so Home
  Assistant can continue sending callbacks to the same app endpoint it just
  paired against.
- Made shuffle and repeat use matching bordered icon-button styling on iOS and
  macOS.
- Changed pairing reset confirmation to an explicit alert and only show the
  reset action when a pairing token is stored.
- Updated the user-facing proposition to "DJConnect. Jouw persoonlijke muziek
  DJ."
- Fixed iPadOS simulator microphone permission handling by using the iOS 17+
  recording-permission API and returning permission callbacks to the MainActor.
- Added album-art thumbnails to queue rows and made queue items playable when
  Home Assistant provides a queue item URI.
- Switched queue item taps away from unsupported `play_queue_item`/`play_uri`
  commands and onto Home Assistant's supported `play_context_at` command.
- Accepted Home Assistant queue responses with top-level `context_uri` /
  `contextUri` so Up Next playback can preserve the active playback context.
- Stored playback `context_uri` / `queue_context` from Now Playing snapshots
  and require that context before enabling queue-item playback.
- Kept volume slider changes optimistic while the backend command is pending
  and added a delayed status refresh after volume commits.
- Moved queue refresh out of the table body into a compact toolbar icon.
- Moved the DJ announcement card to the top of Now Playing.
- Moved output device selection to the bottom of Now Playing.
- Added a delayed follow-up Now Playing refresh after playback-changing commands
  so next/previous track changes update album art reliably.
- Added a delayed follow-up startup/pairing refresh so initial Now Playing
  metadata and album art are corrected after Home Assistant settles.
- Made the output device refresh icon neutral white and increased the Now
  Playing artist text size.
- Added availability-gated Liquid Glass effects to primary card surfaces.
- Reworked About rows so every label is shown above its value.
- Gave settings/about section headers a subtle background band for clearer
  visual separation.
- Normalized About value typography so copyable rows use the same font family
  as the rest of the screen.
- Aligned About content with the ESP client by adding music/backend status and
  legal/notices rows.
- Kept Settings logs pinned to the newest entry and shortened log level labels
  to `INF`, `DBG`, `WRN`, and `ERR`.
- Constrained Now Playing album art to stable square bounds so long artwork
  never pushes title and artist text off screen.
- Forced a full Now Playing refresh after selecting a queue item so the active
  track and album art update after Home Assistant/Spotify settle.
- Moved technical DJ announcement backend errors out of the UI and into logs,
  with a friendly unavailable state and disabled purple microphone styling.
- Added the DJConnect banner to Now Playing and made the iOS navigation title
  appear inline while scrolling.
- Added voice status steps for push-to-talk: listening while recording and
  processing while the WAV upload/DJ response is pending.
- Changed the microphone control to true press-to-hold PTT: press starts
  recording, release stops and uploads the WAV immediately.
- Removed the duplicate Queue section label and added pull-to-refresh for the
  queue list.
- Added a row-level loading spinner while a queue item is being started and the
  Now Playing/queue refresh is still pending.
- Added toolbar refresh spinners for Queue and Playlists, with pull-to-refresh
  waiting for the actual backend refresh to finish.
- Used queue row positions as SwiftUI identities so repeated Spotify tracks in
  the queue no longer trigger duplicate-ID warnings.
- Removed the background bands from About section headers.
- Made the DJ announcement card grow vertically for longer responses instead
  of truncating after two lines.
- Resolved relative DJ response audio URLs against the Home Assistant local URL
  and accepted common audio URL aliases in voice responses.
- Translated Spotify OAuth/backend voice responses into a friendly prompt to
  refresh the Spotify connection in Home Assistant, while keeping the technical
  response in logs.
- Translated STT not-recognized responses to a short user-facing "Niet
  herkend" message.
- Mapped the HA Assist "did not return recognized text" voice failure to the
  friendly Dutch DJ announcement label "Invoer niet herkend".
- Mapped HA Assist `RecognitionStatus` voice failures to the same friendly
  "Invoer niet herkend" DJ announcement label.
- Pinned the Client API url used during pairing until pairing reset so Home
  Assistant keeps calling the same local app endpoint after restarts.
- Extracted the `message` field from JSON server errors before showing DJ
  announcement text, preventing raw JSON from appearing in the UI.
- Added explicit foreground wakeword support with a configurable wake phrase,
  defaulting to "Hey DJ", using Apple Speech while the app is open. Wakeword is
  session-only, does not auto-start after app launch, and is disabled on iOS
  Simulator because simulator speech/audio capture is unstable.
- Stopped sending Spotify `offset_uri` for queue contexts that do not support
  offsets, such as artist contexts, so queue taps avoid Spotify 400 failures.
- Split playlists into a dedicated iOS/macOS page and added the About page to
  the iOS/iPadOS tab bar.
- Restyled playlist rows with primary text and a purple play icon instead of
  default link-colored labels.
- Reworked the default liked-songs playlist row to match queue/playlists rows
  with white text and a trailing play icon.
- Renamed the visible settings diagnostics section to Logs while keeping the
  redacted diagnostics export contract unchanged.
- Normalized playback volume from the active playback device when top-level
  playback volume is missing, fixing the Now Playing slider showing `0`.
- Advanced the playback progress bar locally every second while playback is
  active, with Home Assistant snapshots still correcting the source of truth.
- Added local playback for returned DJ response audio URLs when local response
  audio is enabled.
- Refreshed Now Playing, outputs, queue, and playlists after DJ voice responses
  so playback changes from voice commands appear immediately.
- Added a visible refresh busy state and completion logging for the manual
  Now Playing refresh action.
- Refreshed the rich Now Playing snapshot immediately after playback commands,
  including play and pause, so button state and album art update right away.
- Replaced previous/next transport icons with previous-track/next-track icons
  to better match the actual command semantics.
- Updated the About header to use a full-width DJConnect app banner and show
  the proposition as "Jouw persoonlijke muziek DJ".
- Renamed visible UI labels for the client API URL, DJ announcement, default
  playlist, logs copy action, and related settings/about rows.

## 3.1.0 - 2026-06-10

### Added

- Added a complete native iOS/macOS Xcode project with shared `DJConnectCore`
  and `DJConnectUI` modules, app targets, generated app icons, Keychain token
  storage, and Swift Package/Xcode test coverage.
- Added Home Assistant pairing for Apple app clients with app-generated codes,
  canonical `device_id` identity, bearer-token storage, stale auth handling,
  version mismatch handling, and reset/recovery flows.
- Added native playback controls for play/pause, previous, next, volume,
  shuffle, repeat, output selection, queue loading, playlists, and liked proxy
  through `/api/djconnect/command`.
- Added Push-to-Talk recording with mono PCM WAV upload to
  `/api/djconnect/voice`.
- Added native iOS/macOS UI for setup status, now playing, playback controls,
  queue/playlists, DJ response, settings, language switching, log level, and
  diagnostics.
- Added app logging with log-level filtering, OSLog output, in-app diagnostics,
  stable log row ids, and redacted diagnostics export copy support.
- Added Local Network, Bonjour, local HTTP transport, and Microphone usage
  declarations for Apple platforms.
- Added README, handoff, API contract, architecture, architecture decisions,
  sync prompts, TODO/issues, privacy, release signing, TestFlight,
  notarization, and live HA validation documentation.
- Added tests for status, command, pairing, voice requests, backend
  unavailable, version mismatch, backend collection decoding, and diagnostics
  redaction.

### Changed

- Set app/protocol version to `3.1.0`.
- Kept the Apple app on HA-owned backend routes and removed the local
  `/api/device/*` app endpoint because those routes are reserved for ESP
  hardware clients.
- Improved pairing polling so temporary Home Assistant 401 responses keep the
  app waiting while reset pairing stops cleanly and rotates local identity.
- Improved stale pairing, missing integration-route, backend unavailable, and
  update-required UI states without clearing the Keychain token automatically.
- Expanded `.gitignore` with SwiftPM, Xcode, macOS, Fastlane, CocoaPods, and
  Carthage generated output rules.

### Verified

- `swift test`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
