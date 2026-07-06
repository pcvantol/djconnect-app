# Changelog

All notable changes to DJConnect App are documented here.

## Unreleased

### Changed

- Hardened the app release script to verify the release commit is based on
  `origin/main`, push the exact release commit to `main`, and publish private
  source release notes from only the matching `CHANGELOG.md` version section.

## 3.2.22 - 2026-07-07

### Added

- Added iOS 18 dark and tinted app icon renditions generated from the shared
  DJConnect app icon source.
- Added native haptic feedback for Mood changes, playback starts, queue and
  playlist starts, Discover/Ontdek Play Now, Ask DJ request/response actions,
  and supported watchOS/macOS equivalents.

### Changed

- Made Now Playing, Queue, Ask DJ, Track Insight, and VibeCast widget/visual
  accents follow the selected Mood palette while keeping Track Insight actions
  free of extra haptic feedback.
- Clarified Mood selection copy in all supported app languages.
- Split iOS, macOS, and watchOS app icons into platform-specific asset sets so
  Xcode no longer reports unassigned AppIcon children.

### Fixed

- Fixed the offline Wi-Fi/settings link on iOS so it no longer falls back to
  the DJConnect app settings page before trying system network settings.

## 3.2.21 - 2026-07-06

### Added

- Added support for the Home Assistant `music_discovery_ready` APNs reminder,
  including `djconnect://music-discovery` deep links, Ontdek refresh on receive
  or tap, websocket refresh preference, REST/feed fallback behavior, and
  coalescing for quick receive/tap races.
- Added the shared Mood control to Speelt nu / Now Playing on iOS and macOS.

### Changed

- Documented that Music Discovery reminder pushes are trigger-only: Ontdek
  renders recommendations solely from backend `sections[].items[]`, never from
  push payload content.
- Made the Speelt nu / Now Playing artwork card background respond to the
  selected Mood palette.
- Gave the VibeCast genre badge a larger, more distinctive gradient style that
  follows the selected Mood palette.
- Tightened the Track Insight share popover spacing so the share actions sit
  closer to the preview card.

### Fixed

- Fixed demo VibeCast so changing to the next track while VibeCast is open
  automatically starts Track Insight analysis and refreshes the genre badge.

## 3.2.20 - 2026-07-05

### Fixed

- Fixed public update-check publishing by writing localized and fallback
  `latest.json` release-note manifests to djconnect.dev.

## 3.2.19 - 2026-07-05

### Changed

- Added a Sluiten / Close action below Speel nu / Play now in the Discover
  recommendation detail sheet.

### Fixed

- Fixed the public unsigned iOS release workflow on Xcode 16.4 by treating
  watchOS `UserNotifications` concurrency annotations as preconcurrency.

## 3.2.18 - 2026-07-05

### Added

- Added update checking from the About screen with localized release notes and
  patch-delta summaries.
- Added the VibeCast genre badge from the Home Assistant `context.genre_badge`
  contract, including stale-data clearing coverage.
- Added iPhone landscape-orientation support metadata and scene refresh.

### Changed

- Polished iPhone Discover, More, Ask DJ, Track Insight, Music DNA, pairing, and
  Home Screen shortcut presentation.
- Made compact iPhone Music DNA and Track Insight card groups horizontally
  scrollable so cards keep usable sizing.
- Matched Music DNA hero width to the Track Insight canvas layout.

### Fixed

- Fixed QR scanner focus/exposure for pairing codes.
- Fixed Ask DJ keyboard focus state publishing and the prompt-field auto-dismiss
  regression.
- Fixed Xcode warnings around SwiftUI focus updates, app icon placeholders,
  watch proxy payload decoding, and QR camera configuration.

## 3.2.17 - 2026-07-05

### Changed

- Updated every Home Assistant DJConnect HTTP route used by the Apple clients to
  the canonical `/api/djconnect/v1/...` prefix.
- Updated pairing QR/deep-link payloads to advertise
  `pair_path=/api/djconnect/v1/pair` while keeping legacy pair-path parsing for
  existing setup links.
- Refreshed API, architecture, handoff, release, README, and chat-bootstrap
  documentation for the canonical v1 route prefix.

### Fixed

- Added regression coverage so hardcoded client-call routes cannot silently
  fall back to the old `/api/djconnect/...` prefix.
- Kept backend-provided image, TTS, and audio URLs intact instead of rewriting
  server-returned media paths on the client.

## 3.2.16 - 2026-07-04

### Added

- Added Music DNA export/import actions to iOS and macOS Settings using native
  Apple save/import sheets.
- Added authenticated HTTP Music DNA export support for
  `/api/djconnect/v1/music_dna/export`, saving the exact server-built JSON envelope
  instead of reconstructing exports from cached profile data.
- Added Music DNA import preview and upload support for previously exported JSON
  backups, with connected/pairing guards and clear success/error states.

### Changed

- Updated the Music DNA, Discover, Ask DJ, Track Insight, toast, hero, and
  localization polish across iOS and macOS.
- Documented release hygiene that app-facing translations must be reviewed in
  all five supported languages before release.

### Fixed

- Fixed stale Music DNA opt-in prompts when Home Assistant is unavailable or the
  music backend token has expired.
- Fixed Music DNA export/auth failures to use the existing DJConnect pairing
  recovery flow.

## 3.2.15 - 2026-07-04

### Added

- Added Ontdek / Discover as a first-class iOS/macOS Music Discovery page backed
  by the new Home Assistant Music Discovery endpoints.
- Added the iOS Home Screen quick action `dev.djconnect.action.discovery` for
  jumping directly to Discover/Ontdek.

### Changed

- Moved Queue into More on compact iOS navigation so Discover can sit directly
  after Track Insight in the main tab set.

### Fixed

- Fixed iOS/watchOS release builds by keeping APNs entitlement lookup on
  platforms where the Security task API is available.
- Fixed watchOS Music DNA rendering for backend responses that omit optional
  profile lists.

## 3.2.14 - 2026-07-04

### Added

- Added iOS/macOS VibeCast feed support for `/api/djconnect/v1/vibecast`, including
  shared response models, authenticated parity request metadata, polling while
  the VibeCast surface is visible, and side bubbles for structured facts/trivia.
- Added optional WebSocket fast-path support for the `djconnect/vibecast` route
  with the same HTTP fallback behavior as Ask DJ and Track Insight.
- Made active iOS/macOS VibeCast sessions auto-analyze Track Insight for the
  current and next playing tracks until the VibeCast surface is closed.

### Fixed

- Made the no-output startup regression test locale-independent so release CI
  passes on runners whose default app language is Dutch.

## 3.2.13 - 2026-07-04

### Added

- Added iOS/macOS VibeCast feed support for `/api/djconnect/v1/vibecast`, including
  shared response models, authenticated parity request metadata, polling while
  the VibeCast surface is visible, and side bubbles for structured facts/trivia.
- Added optional WebSocket fast-path support for the `djconnect/vibecast` route
  with the same HTTP fallback behavior as Ask DJ and Track Insight.
- Made active iOS/macOS VibeCast sessions auto-analyze Track Insight for the
  current and next playing tracks until the VibeCast surface is closed.

## 3.2.12 - 2026-07-04

### Changed

- Regenerated iPhone, iPad and Apple Watch screenshots for the updated
  Track Insight, Music DNA, Ask DJ and watchOS visual states.
- Updated screenshot documentation with the latest simulator capture date.

## 3.2.11 - 2026-07-04

### Added

- Added mood-aware Ask DJ assistant bubbles on iOS, macOS, and watchOS using
  structured `mood` / `mood_context` metadata.
- Added richer Music DNA dashboard decoding for backend mood averages,
  energy profiles, and recent analysis signals.
- Added Music DNA and Track Insight visual parity updates for Apple Watch,
  sharing, and AirPlay/VibeCast output surfaces.

### Changed

- Updated Ask DJ follow-up actions such as "Meer van deze artiest" to send a
  new Ask DJ text request instead of an empty playback command.
- Made Track Insight refresh and rendering respect mood overrides more
  consistently across live, share, and output contexts.
- Improved Track Insight progress visuals and analysis/metric section icons.

### Fixed

- Fixed stale Track Insight content on Apple Watch when playback changes.
- Fixed overly aggressive Ask DJ keyboard dismissal while typing.
- Fixed iPhone Track Insight width overflow and smoother playback progress
  animation.

## 3.2.10 - 2026-07-02

### Added

- Added an opt-in WebSocket fast-path toggle for local Home Assistant
  connections on iOS and macOS.
- Added direct screenshot launch routing for deterministic iPhone and iPad
  capture runs.

### Changed

- Refined Settings, Logs, Music DNA, Track Insight, onboarding and pairing
  layouts across iOS, iPadOS and macOS.
- Regenerated iPhone, iPad and Watch screenshots for the updated UI.
- Updated Ask DJ permission prompts so notifications are requested first and
  microphone access is requested only from voice actions.

### Fixed

- Fixed iPhone rotation behavior for Games and Music DNA by switching to a
  geometry-aware top-tab layout in landscape.
- Fixed remaining wake-word copy escaping and untranslated Track Insight text.
- Fixed home-screen jump actions and several row-height/padding inconsistencies.

## 3.2.9 - 2026-07-02

### Added

- Added a richer vector launch visual for the macOS splash screen.
- Added stronger regression coverage for Ask DJ history clearing across HTTP,
  WebSocket and Apple client identity payloads.

### Changed

- Improved wide iPad/macOS layouts for Track Insight, Music DNA, local games,
  About, Legal and Privacy pages.
- Made iPad sheets and QR scanning use more of the available canvas.
- Refined iOS More-menu ordering and labels, permission copy, action icons and
  output-device accent colors.

### Fixed

- Fixed Ask DJ chat clearing so successful clear responses immediately empty
  the local cache on iOS, macOS and watchOS.
- Fixed clear-history identity payloads to include the canonical Apple
  `device_id`, `client_id`, `client_type` and `device_name`.
- Fixed Track Insight export UI so the action button no longer shifts while
  progress updates.
- Fixed iPad/macOS card grids and row heights that left unused space or uneven
  rows.

## 3.2.8 - 2026-07-01

### Added

- Added shared localization coverage for the Apple clients with supported
  languages `en`, `nl`, `de`, `fr`, and `es`.
- Added localized pairing/API error presentation for stale auth,
  `client_type_mismatch`, `invalid_client_type`, `invalid_pair_code`,
  `not_configured`, and unauthorized pairing responses.
- Added a localization validation script that fails when supported locales are
  missing keys or format placeholders drift.

### Changed

- Centralized pairing error copy so iOS/iPadOS, watchOS, and macOS use the same
  user-facing messages while protocol values remain unchanged.
- Documented that future Apple client UI text must be localized for all
  supported languages in the same pull request.

### Fixed

- Kept manual pairing errors free of raw backend/debug jargon while preserving
  existing Home Assistant setup-flow guidance.

## 3.2.7 - 2026-06-30

### Added

- Added pairing coverage for ngrok development tunnels, URL syntax validation,
  two-phase Home Assistant setup completion, and `client_type_mismatch`.
- Added regression coverage for Track Insight `client_type`, Ask DJ history
  sync preserving fresh exchanges, and stale Music DNA profile refreshes.

### Changed

- Matched Music DNA outline-heart iconography across Watch, iOS, and macOS.
- Restyled iOS/macOS output-device choices to feel closer to the Apple Watch
  selector.
- Improved pairing copy and validation for local URLs, local-development ngrok
  URLs, invalid pairing codes, and wrong Home Assistant app-type selections.

### Fixed

- Fixed Track Insight requests missing the canonical Apple client type.
- Fixed Ask DJ answers disappearing after a later history/status sync.
- Fixed Music DNA toggles visually reverting when Home Assistant returned a
  stale profile immediately after opt-in or opt-out.

## 3.2.6 - 2026-06-30

### Added

- Added an iOS camera consent sheet before QR pairing and restored the required
  camera usage description.
- Added Dutch widget and Watch complication metadata localizations.
- Added documentation and tests for deep links, quick actions, camera consent,
  and supported Bonjour service declarations.

### Changed

- Made iOS home-screen quick actions and widget taps route reliably to the
  matching app page.
- Improved demo-mode widget refreshes for Now Playing, Queue, Playlists, Track
  Insight, and Ask DJ.
- Smoothed Track Insight and VibeCast visualizer animation while playback is
  active.
- Matched Watch Music DNA iconography and button alignment with iOS/macOS.
- Refined Track Insight share preview/export sizing so preview scaling does not
  alter exported content.

### Fixed

- Fixed macOS build availability around external playback preview settings.
- Fixed iOS permission-settings return flow, demo playback controls, and Watch
  install/startup regressions.

## 3.2.5 - 2026-06-30

### Changed

- Split iPhone and Apple Watch pairing into explicit QR/manual flows so the
  iPhone shows only the relevant pairing action for the active device.
- Clarified Apple Watch pairing success on both iPhone and Apple Watch.
- Restyled the Music DNA opt-in prompt to match the Feedback sheet.
- Refined Track Insight privacy and logs UI with a lock footer icon and muted
  log line numbers.

## 3.2.4 - 2026-06-29

### Added

- Added first-class Music DNA profile loading, opt-in, opt-out, clear, demo,
  refresh, and empty/error states across iOS, macOS, and watchOS.
- Added Apple Watch Music DNA screens, consent from both Ask DJ and Music DNA,
  and Music DNA controls in Watch Settings through the iPhone proxy.

### Changed

- Kept Music DNA server-side as the source of truth and stopped deriving a
  persistent profile from local Track Insight history.
- Updated Music DNA and Watch proxy tests plus the Home Assistant API contract
  documentation.
- Removed the remaining Apple local API/Bonjour pairing legacy and documented
  inbound-only pairing through Home Assistant `/api/djconnect/v1/pair`.

### Removed

- Removed old local `/api/device/*` callback/discovery compatibility,
  Bonjour/mDNS service declarations, and local-device API release tooling.

## 3.2.3 - 2026-06-29

### Changed

- Refined the iOS Track Insight screen with native large-title navigation,
  reordered insight cards, adaptive metric tiles, and default-colored toolbar
  sharing.
- Reworked Track Insight share controls, copy, scrolling, cancellation, and
  animated card visuals.
- Reduced Track Insight visualizer CPU load with async Canvas rendering,
  Metal-backed compositing, a 30 FPS animation cadence, and offscreen animation
  shutdown.

## 3.2.2 - 2026-06-28

### Added

- Added Track Insight and Ask DJ widgets for iOS and macOS, plus Track Insight
  Live Activity/Dynamic Island rendering on iPhone.
- Added on-device Track Insight sharing with static and animated formats for
  story, square, and landscape cards.
- Added an optional local Home Assistant native `/api/websocket` fast path for
  latency-sensitive command, Ask DJ message, and Track Insight actions, with
  HTTP remaining the canonical fallback.
- Added iOS Home Screen quick actions for Ask DJ and Track Insight.

### Changed

- Aligned the Apple clients with the Home Assistant 3.2.2 Ask DJ and Track
  Insight contract, including Music DNA terminology and `music_dna_key`
  payloads.
- Reworked Track Insight navigation and toolbar actions so Share, Refresh, and
  VibeCast/AirPlay live in the Track Insight toolbar instead of a separate
  VibeCast screen.
- Updated Demo Mode Track Insight visualizations to map demo playback to
  distinct local insights.

### Removed

- Removed old memory terminology from the active client contract; Music DNA is
  now the visible and code-facing label.
- Removed old Ask DJ non-Track Insight analysis rendering and local Track
  Insight prompt classification.

## 3.2.0 - 2026-06-26

### Changed

- Clarified LAN-only pairing and post-pairing remote URL fallback guidance in
  the iOS/macOS pairing sheet and watchOS companion pairing view.
- Added route, backend, and playback-state details to the runtime status
  surface.
- Expanded diagnostics export and release docs with TestFlight/App Store
  readiness fields and redaction expectations.
- Synced the Apple client contract with Home Assistant `3.2.x` backend error
  shapes by accepting object-form `music_backend_error` and the shared
  `windows` client type in core models.
- Added VibeCast artist shout-out image decoding from proxied Home Assistant
  artwork URLs with text-only fallback behavior.

- Bumped the Apple client protocol/app version line to `3.2.0`.
- Added Home Assistant local/remote transport selection for iOS and macOS after
  successful local pairing, with `local`, `remote`, and `offline` diagnostics.
- Parsed and surfaced the 3.2 music-backend summary fields for pairing,
  status, command, and Ask DJ responses.
- Disabled Apple client-hosted local `/api/device/*` pairing/callback API and
  `_djconnect._tcp` advertising for iOS/macOS/watchOS.
- Moved watchOS runtime HA traffic to the paired iPhone proxy for status,
  commands, Ask DJ history, clear history, idle suggestions, voice upload, and
  push registration; the Watch now shows compact iPhone connection/backend
  state and no longer uses direct HA networking.
- Preserved backend-owned Ask DJ action payloads for Spotify Direct and Music
  Assistant and forwarded `music_backend_revision` with action commands.

## 3.1.53 - 2026-06-26

### Changed

- Added forward-compatible client decoding for Ask DJ technical track analysis
  provider status metadata via optional `analysis.providers[]`, while keeping
  `sections[]`, `timeline[]`, and `dj_tips[]` authoritative for the normal
  analysis UI.
- Added coverage for provider status fixtures with known, missing, unavailable,
  and future/unknown provider values.

## 3.1.52 - 2026-06-26

### Changed

- Reworked watchOS pairing to be fully companion-only: the Watch no longer hosts
  a local Web API, no longer advertises Bonjour/mDNS, and no longer runs a
  direct Home Assistant pairing poll.
- Added the iPhone-mediated Watch proxy contract: the iPhone publishes the Watch
  identity, handles Home Assistant local callbacks, and forwards commands, DJ
  responses, pairing results, and forget requests to the Watch over
  WatchConnectivity.
- Updated Watch pairing UI to show only the Watch pairing code and iPhone
  companion status, removing the Watch-side Home Assistant URL and Client adres
  controls.
- Updated Watch companion-only documentation across the API contract, handoff,
  README, and chat bootstrap.

## 3.1.51 - 2026-06-25

### Changed

- Documented the Ask DJ history-clear endpoint as
  `/api/djconnect/v1/ask_dj/history/clear`, with `clear_revision` as the
  authoritative full-clear signal for cached Apple-client history.
- Updated the Ask DJ action contract so Apple clients preserve backend-returned
  action objects, including object-valued `value` payloads, when sending
  follow-up, recommendation, confirmation, or output commands back to Home
  Assistant.
- Included explicit `client_id`, `device_id`, `device_name`, and `client_type`
  identity fields in Ask DJ text and command payload documentation.
- Added the Ask DJ `track_insight` read-only intent contract and client
  decoding for structured Track Insight metadata and metric items.

## 3.1.50 - 2026-06-25

### Changed

- Ask DJ now scrolls to the newest message every time the chat opens on iOS,
  macOS, and watchOS, including after async history loading settles.
- Restyled the Ask DJ scroll-to-bottom affordance to match the DJConnect
  gradient button language.
- Added privacy-safe diagnostics for APNs push registration and backend push
  status on Apple clients.

### Fixed

- Hardened standalone watchOS pairing by keeping the local device API on a
  stable stored port, publishing mDNS only after the listener is ready, binding
  the listener to IPv4 LAN interfaces, keeping it alive during active pairing,
  and logging listener state transitions.
- Added watchOS LAN IPv4 diagnostics when the Watch is connected through
  iPhone/Bluetooth relay or another non-LAN path.

## 3.1.49 - 2026-06-25

### Changed

- Ask DJ speaker/output responses now render as vertical rows with the speaker
  name on the left and the active/activate button on the right.
- Ask DJ now scrolls to the bottom when opening the chat history, including
  after the first async history load.

## 3.1.48 - 2026-06-25

### Added

- Added app, status, and pairing fields to the local device API so Home
  Assistant can show iPhone and Watch sensors with concrete values instead of
  unknown placeholders.

### Changed

- Made Apple Watch Now Playing refresh show a busy state, prevent duplicate
  refreshes, and temporarily disable transport and volume controls while the
  status request is running.
- Rendered Ask DJ speaker/output responses as list rows with a right-aligned
  activate button, matching playlist and album action cards.
- Prefer usable LAN IPv4 addresses for local pairing and hide unusable Watch
  fallback addresses when no reachable local network address is available.
- Only throttle backend collection refreshes after at least one devices, queue,
  or playlist refresh succeeds.

### Fixed

- Fixed Dutch What's New publication by adding localized release-note source
  files for this release so the public workflow no longer falls back to English
  content for `nl` URLs.

## 3.1.47 - 2026-06-24

### Added

- Added the interactive first-run onboarding tour across iOS, macOS, and
  watchOS with tappable feature highlights for Now Playing, Ask DJ, Queue,
  settings, and Mini-games.
- Added watchOS top refresh controls for Now Playing, output devices, playlists,
  and queue, with automatic refresh when opening those screens.

### Changed

- Updated watchOS Now Playing, queue, playlist, output, logs, About, settings,
  and Ask DJ layouts for smaller watch screens and more reliable navigation.
- Made watchOS playback commands refresh their playback snapshot after commands
  so next/previous, queue item starts, output changes, and volume updates stay in
  sync with Spotify/Home Assistant.
- Simplified Ask DJ confirmation actions to direct "Ja graag" and "Nee dank je"
  buttons without media-card styling.

### Fixed

- Fixed Ask DJ chat ordering for the server-side message exchange contract by
  respecting `exchange_id` and `exchange_order` while deduplicating HTTP,
  push, and history sync updates.
- Fixed watchOS mDNS/local API lifecycle churn that could leave duplicate
  listeners or drive high CPU and memory usage.
- Fixed watchOS queue context retention and automatic queue refresh after
  starting an item from the queue.
- Fixed watchOS voice recording and log level crashes on simulator/watchOS by
  avoiding unstable render/audio state transitions.
- Fixed log rendering, selection, search dismissal, and focus styling so logs
  remain selectable and easier to inspect.

## 3.1.46 - 2026-06-23

### Changed

- Documented the expanded Bonjour/mDNS discovery TXT contract, including
  `pairing_status`, pairing-code aliases, local device API paths, and
  standalone watchOS troubleshooting.
- Made iOS fallback local-device identity platform-correct if the local API info
  provider is invoked after the app model is gone.

### Fixed

- Fixed standalone watchOS mDNS discovery by advertising the Watch as
  `client_type=watchos` with the `djconnect-watchos-` device ID, the reachable
  local URL, pairing metadata, and `/api/device/*` paths.
- Prevented stale watchOS Network.framework listeners from leaving duplicate
  `_djconnect._tcp` services on different ports.
- Restarted watchOS local discovery when the app returns to foreground, pairing
  starts or resets, or WiFi becomes available again.
- Reduced watchOS demo-mode CPU and memory churn by lazily rendering the Now
  Playing page, disabling demo Crown focus churn, and stopping demo diagnostics
  publishers.
- Removed the oversized watchOS top refresh button and suppressed demo haptics
  that could produce noisy OSStatus logs on Apple Watch.

## 3.1.45 - 2026-06-23

### Changed

- Documented Ask DJ morning-start metadata and backend-owned follow-up/
  confirmation actions in the README, architecture notes, and API contract.
- Hardened Apple APNs push registration for iOS, macOS, and watchOS by using a
  full registration fingerprint, decoding Home Assistant push status fields,
  avoiding raw APNs token storage, and keeping push troubleshooting logs
  privacy-safe.
- Matched Ask DJ assistant response bubbles and setup/status blocks to the
  warmer Games gradient styling.

### Fixed

- Removed the blue selected focus ring from the Ask DJ search bar, made the
  toolbar search button toggle the search field closed again, and highlighted
  matches while typing.
- Made the Ask DJ search placeholder emphasize `Ask DJ`.
- Replaced the default macOS About popup with the in-app About view, fixed the
  transparent/wide About window edges, and made the Settings window tall enough
  to avoid immediate scrolling.
- Reduced repeated Home Assistant connection noise by suppressing unavailable
  image retries and avoiding playback polling while the backend is unavailable.

## 3.1.44 - 2026-06-23

### Added

- Render Ask DJ recently played history for tracks, albums, artists, and
  playlists as compact informational lists without reconstructing playback
  actions client-side.

### Changed

- Improved Ask DJ rich chat rendering for mood/status messages, playlist and
  album action rows, and album artwork sizing across iOS and macOS.
- Kept macOS mood controls aligned and prevented the expanded mood panel from
  shifting the sidebar or Ask DJ chat layout.

### Fixed

- Fixed macOS Home Assistant pairing discovery by keeping the local mDNS
  advertisement alive during pairing and regenerating stale local pairing codes
  without stopping the pairing flow too early.
- Prevented Ask DJ text-only and recent-history responses from showing stale
  artwork from previous chat bubbles.

### Removed

- Removed the discontinued Apple display feature from the Apple apps, including
  its UI, local serving path, demo launch flag, and screenshot coverage.

## 3.1.43 - 2026-06-20

### Changed

- Render Ask DJ assistant answers as rich chat content with preserved headings,
  blank lines, paragraphs, bullets, links, sources, images, audio replay, and
  structured playback/action rows across Apple clients.
- Send the full known Ask DJ action object back to Home Assistant command
  handling, including labels, reasons, artwork URLs, output state, and
  confirmation response values.
- Avoid reusing images, links, or action rows from older Ask DJ bubbles when a
  refreshed server message omits them or sends empty arrays.
- Improved watchOS runtime behavior for pairing, local API lifecycle, demo
  mode, wakeword scheduling, diagnostics, and notification delegate handling.

## 3.1.42 - 2026-06-20

### Changed

- Added a confirmation dialog before resetting the app pairing from Settings on
  iOS, macOS, and watchOS.

## 3.1.41 - 2026-06-20

### Added

- Added APNs push registration on iOS, macOS, and watchOS, including privacy
  disclosure text and Home Assistant registration/unregistration calls.
- Added a much richer watchOS experience with welcome/pairing/about/legal/
  privacy/logs/settings screens, output selection, playlists, queue, games,
  complications, volume control, foreground-only voice activation, haptics, and
  Crown mood scrubbing.
- Added CI validation for the committed Postman collection.

### Changed

- Updated iOS/macOS button styling to use readable blue-purple gradient pills
  with white text, matching the watchOS visual language.
- Made pairing stricter on fresh iOS/macOS installs by ignoring orphaned
  persistent device tokens without a matching install identity.
- Improved Watch pairing copy, WiFi/local-network handling, demo-mode exit
  behavior, and Now Playing artwork/output layout.

## 3.1.40 - 2026-06-20

### Added

## 3.1.38 - 2026-06-20

### Changed

- Added Ask DJ support for backend-generated ambient/system messages, including
  Spotify playback-context DJ facts with distinct chat styling across Apple
  clients.
- Changed the Ask DJ clear-history confirmation from a popover-style
  confirmation dialog to a standard modal alert with explicit cancel and
  destructive actions.
- Changed Ask DJ Demo Mode to stay fully client-side: it shows the starter
  prompts, avoids backend history sync, and answers locally until Home
  Assistant is paired.
- Removed raw inline Ask DJ error text above the prompt; failures are surfaced
  through the existing snackbar/toast.
- Added a microphone icon to Ask DJ voice-request chat bubbles.
- Replaced Keychain-backed DJConnect device-token storage with app-private
  storage on iOS, macOS, and watchOS to avoid platform Keychain prompts.
- Added an `App opnieuw koppelen` Settings action that resets pairing and opens
  the pairing sheet again.

### Fixed

- Ignored cancelled Ask DJ history refresh tasks so pull-to-refresh does not
  show a spurious network-cancelled error.
- Prevented raw backend/HTML error bodies from appearing in Ask DJ chat or
  inline error UI; technical details remain in diagnostics logs only.

## 3.1.36 - 2026-06-19

### Added

- Added Watch-side Home Assistant pairing through the same mDNS/local device API
  flow used by iOS and macOS, including a pairing success screen after Home
  Assistant completes the pairing request.
- Added Watch demo mode with local demo playback controls and a sample Ask DJ
  voice response.

### Changed

- Moved the local device API into the shared Core module so iOS, macOS, and
  watchOS can use the same pairing contract.
- Updated Ask DJ text chat to request `audio_response: auto`, treat missing
  `audio_url` as normal for informational answers, and use top-level audio URLs
  as fallback for assistant message replay.
- Added pull-to-refresh to the Ask DJ chat so users can manually sync chat
  history with Home Assistant.
- Added a long-press context menu on Ask DJ chat bubbles to place an existing
  message back into the prompt for editing or resending.
- Removed the redundant Now Playing DJ request block so voice and text music
  requests live in the richer Ask DJ screen.
- Updated handoff, API contract, architecture, release, and bootstrap prompts
  to reflect Ask DJ as the single rich Apple-client DJ request surface.
- Documented the Ask DJ `change_music_context` intent for requests such as
  `Ik wil wat anders horen`.

### Fixed

- Fixed macOS stale-token recovery so a rejected device token clears locally and
  re-enables Bonjour pairing discovery for Home Assistant.
- Fixed iPhone Ask DJ keyboard handling so tapping or scrolling the chat closes
  the keyboard, and added a keyboard `Done` control.

## 3.1.35 - 2026-06-19

### Added

- Added a standalone native watchOS DJConnect client target with Home Assistant
  pairing, playback controls, `Ask DJ` push-to-talk WAV voice upload, and Watch
  speaker DJ response playback.
- Added Watch-side `Ask DJ` mood and Music DNA context hints for future
  server-side Music DNA support in the Home Assistant integration.
- Added `Ask DJ` as a first-class iOS/macOS chat screen with local chat
  history, text input, clickable starter prompts, timestamps, clear-history
  coordination, retry states, toast errors, markdown, sources, links, images,
  and replayable DJ response audio.
- Added Ask DJ voice input on iOS/macOS through a push-to-talk microphone in
  the chat input bar.
- Added Ask DJ support for image attachments, multiple images, hyperlinks,
  embedded link previews, rich sources, and audio replay/stop controls across
  Apple clients.
- Added backend contract documentation for Music DNA, personal listening
  profile analysis, personal recommendations, Spotify recently played/top
  profile usage, voice Ask DJ, and explicit `Play Now` recommendation actions.
- Added client-side `Play Now` buttons for structured Ask DJ recommendation
  actions, with backend-owned Spotify playback via
  `ask_dj_play_recommendation`.

### Changed

- Styled Ask DJ chat bubbles and input controls with the DJConnect blue/purple
  visual language and replaced the empty-state starter prompt with
  `Verras me met nieuwe muziek`.
- Moved generated simulator screenshots and screenshot folders into `.gitignore`
  so local iOS/macOS/watchOS captures do not enter the repository.

## 3.1.34 - 2026-06-18

### Fixed

- Fixed macOS mDNS pairing discovery by serving the local device API on the LAN
  address advertised in `local_url` and enabling the macOS network server
  entitlement.
- Added local device API request logging for remote address, path, Host header,
  and response status to make firewall and Home Assistant discovery issues
  diagnosable.
- Avoided showing stale pinned Client address values while the app is still
  unpaired or waiting for pairing.
- Documented macOS firewall and third-party security software troubleshooting
  for Home Assistant discovery, including ESET-style connection resets.

### Changed

- Removed duplicate Home Assistant and Spotify notice rows from About because
  the same information already exists in the dedicated connection and legal
  screens.
- Aligned the CI job name with branch protection and made release-blocking tests
  locale independent.

## 3.1.33 - 2026-06-18

### Changed

- Hardened the public GitHub repository settings by enabling secret scanning,
  push protection, Dependabot alerts, Dependabot security updates, and main
  branch protection.

## 3.1.32 - 2026-06-18

### Changed

- App UI language now follows the device language instead of a stored app
  preference or Home Assistant pairing response, and What's New release notes
  use the same resolved language.
- Settings now shows the app language as device-driven rather than offering a
  separate in-app language picker.
- Localized the launch/about tagline for English devices.
- Matched the macOS game selector to the iOS segmented pill style.
- Kept the app's dark DJConnect surfaces, text, and game backgrounds stable
  when the device is in light mode.

### Tests

- Added an English iPhone UI regression test for device-language navigation.
- Verified iPhone screenshots in English demo mode, plus iOS and macOS debug
  builds.

## 3.1.31 - 2026-06-18

### Added

- Prepared a manual-only GitHub Actions TestFlight beta workflow with explicit
  version/tag confirmation and protected-environment signing requirements.
- Updated repository hygiene guidance for AI-assisted development, security
  handling, release docs, TestFlight gating, and fresh Codex chat bootstrap
  state.
- Added `DEVELOPMENT_ENVIRONMENT.md` for local machine, toolchain, simulator,
  signing, and hygiene setup.
- Added Dutch `v3.1.30` What's New release notes so localized iOS/macOS update
  screens do not fall back to English text.
- Added a foreground Now Playing poll so playback controls stay refreshed even
  when playback is paused or changed outside the app.
- Added an AI/Assist disclaimer noting that answers can be incorrect and depend
  on the user's own Home Assistant and Assist configuration.
- Fixed Dutch What's New display for app version `3.1.30` when stale public
  release-note JSON still contains English changelog text, and render What's
  New Markdown instead of showing raw Markdown markers.
- Fixed What's New layout so Markdown headings and bullet lines keep their
  intended spacing on macOS and iOS.
- Documented canonical Home Assistant voice intent examples for
  `current_track` and `playback_control`, including that the app only uploads
  voice audio and does not need Spotify credentials or local playback logic for
  those intents.

## 3.1.30 - 2026-06-18

### Changed

- Added community documentation with a Code of Conduct and private security
  reporting policy for `security@djconnect.dev`.
- Documented the release-cycle requirement to keep the Codex chat bootstrap
  prompt current for each release.
- Renamed the chat bootstrap prompt to `CHAT_BOOTSTRAP.md` for clearer repo
  onboarding.

## 3.1.29 - 2026-06-18

### Changed

- Documented and implemented language-specific static What's New release notes
  so the app can load Dutch or English changelog JSON from `djconnect.dev`
  based on the selected app language.
- Updated release documentation and hygiene notes for maintaining localized
  release-note Markdown/JSON alongside the existing public GitHub releases.
- Documented the Home Assistant integration removal of `spotify_source` and
  `liked_proxy_playlist_uri` user settings; clients keep sending generic
  backend-mediated playback commands and no longer expose those overrides.
- Added a standalone MIT `LICENSE` file and updated repository license
  documentation.

## 3.1.28 - 2026-06-18

### Changed

- Polished the pairing flow with a confirmed Home Assistant address state,
  clearer Home Assistant setup guidance, copy feedback, and wrapping status
  text on iOS and macOS.
- Moved the Home Assistant address display into About > Connection, removed
  duplicate connection rows from Settings/About, and renamed user-facing
  Client API wording to `Client adres`.
- Improved DJ response presentation, listening indicators, voice audio cues,
  and recovery from HTML/backend error pages.
- Expanded local games with richer animations, power pellets, varied
  obstacles, 8-bit sounds, haptics, slower Meteor Run pacing, and clearer
  controls.
- Allowed podcast/queue items to start by URI when no Spotify queue context is
  available.
- Updated release automation to publish static platform-specific release note
  files and moved GitHub Actions checkout usage to the current action version.

### Tests

- Added coverage for podcast queue item starts without playback context and
  suppression of HTML backend error pages in DJ responses.
- Verified Swift build compilation during the release cycle; one local network
  stability test remains flaky with `NSURLErrorDomain -1005`.

## 3.1.27 - 2026-06-16

### Changed

- Load in-app What's New notes from static `djconnect.dev` JSON files first,
  with GitHub release metadata retained only as a fallback.
- Added public-release workflow publication of static platform-specific
  release-note `.md` and `.json` files to the website repository.
- Removed the sticky compact app banner from the Now Playing flow on iPhone and
  Mac, keeping only the regular in-page banner.

### Tests

- Added coverage for the static What's New release-note URLs and GitHub
  fallback URLs.

## 3.1.26 - 2026-06-16

### Changed

- Polished Now Playing DJ response presentation and local response audio
  recovery after voice requests.

### Tests

- Added coverage for DJ response audio URL redaction.

## 3.1.25 - 2026-06-16

### Changed

- Aligned the Apple app playback contract with the canonical Home Assistant
  sync prompt, including playlist aliases, 100-item app limits, recoverable
  backend states, local Client API/mDNS metadata, and wakeword status payloads.
- Added start/stop microphone audio cues for push-to-talk and wakeword-triggered
  voice requests.

### Tests

- Verified Swift tests and iOS/macOS debug builds during the 3.1.25 release
  cycle.

## 3.1.24 - 2026-06-15

### Changed

- Added an editable Home Assistant URL field to the shared Pairing screen and
  made the Settings URL display read-only.
- Improved Pairing screen recovery so the local Client API and mDNS advertising
  restart automatically after URL edits and app resume when pairing is still
  pending.
- Added immediate validation feedback for invalid Home Assistant URLs on the
  Pairing screen.
- Renamed the Pairing success action to "Let's Rock!".
- Hid the permissions request button once Microphone and Speech Recognition
  permissions are both granted.
- Clarified the wakeword status when voice activation is enabled but paused
  because Home Assistant, playback backend, or voice requests are unavailable.
- Added automatic playback backend recovery refreshes while Home Assistant is
  reachable but reports the playback backend as temporarily unavailable.
- Replaced technical pairing backend errors with user-friendly recovery
  instructions.
- Refreshed macOS/iOS permission states when returning from System Settings and
  resumed permission callbacks on the main actor.

### Tests

- Verified Swift tests and iOS/macOS debug builds during the 3.1.24 release
  cycle.

## 3.1.23 - 2026-06-15

### Changed

- Slowed Maze Chase ghost movement and added power-pellet behavior: eating the
  white pellet now makes the ghost temporarily vulnerable with blinking feedback
  and bonus scoring.
- Polished iOS and macOS layout spacing so Now Playing, Queue, Playlists,
  Games, Settings, More, About, Legal, and Privacy align more consistently.
- Updated the DJConnect app banner, splash/crash surfaces, app-gradient
  presentation, and visible version information.
- Improved Home Assistant and playback-backend offline handling: refreshes time
  out cleanly, controls disable during refresh, stale state is reset, and
  wakeword listening pauses while Home Assistant or playback is unavailable.
- Improved push-to-talk and wakeword permission handling, including macOS
  Microphone and Speech Recognition status refreshes after returning from
  System Settings.
- Simplified Settings by keeping the pairing code on the Pairing screen only
  and removing the reset-app-permissions action.
- Added UI-only log line numbering and a copy confirmation toast for logs.
- Added release hygiene preflight tooling for third-party dependency/tool
  updates and documented third-party notices and technical design decisions.

### Tests

- Verified Swift tests and iOS/macOS debug builds during the 3.1.23 release
  cycle.

## 3.1.22 - 2026-06-14

### Changed

- Strengthened the shared DJConnect lilac button style so crash-report,
  feedback, What's New, and other pill-style actions no longer fall back to
  system-blue button tinting.
- Adjusted the iOS audio session options used by voice recording and demo
  response playback so the unsigned public iOS build remains compatible with
  the GitHub Actions Xcode runner.

### Tests

- Verified the Swift test suite after the button-tint and iOS build
  compatibility changes.

## 3.1.21 - 2026-06-13

### Added

- Added a Postman collection for the local iOS/macOS Client API, covering
  pairing info, Home Assistant pairing callback, authenticated command,
  DJ-response, and forget callbacks.

### Changed

- Changed app bundle identifiers to the `dev.djconnect...` namespace.
- Updated all in-app, release, and documentation website links to
  `https://djconnect.dev`.
- Polished macOS/iOS status and diagnostics surfaces: macOS pairing icons now
  use status-dependent colors, the iOS Logs title collapses into a centered
  navigation title, and the More menu table uses the DJConnect table styling.
- Localized the Dutch What's New title to `Wat is er nieuw?`.
- Replaced remaining system-blue action/link styling with the DJConnect lilac
  accent across crash reporting, feedback, What's New, copy actions, settings,
  website links, and pairing/wakeword prompts.
- Matched the iOS Now Playing DJ request and output cards to the connected
  status card styling.
- Updated the public unsigned release workflow to keep iOS and macOS public
  releases separated and clean up old platform releases/tags after publishing.

### Tests

- Updated version and localization coverage for the 3.1.21 app release.

## 3.1.19 - 2026-06-13

### Added

- Added a GitHub Actions workflow that publishes unsigned macOS and iOS build
  artifacts to `pcvantol/djconnect-app-releases` when a release tag is pushed
  or the workflow is started manually.
- Added a version-aware `Wat is er nieuw` / `What's New` sheet. After an app
  update, DJConnect fetches the release body for the current version from the
  public releases repository and shows it once on startup.
- Split public unsigned release publication into platform-specific GitHub
  releases: `ios/vX.Y.Z` and `macos/vX.Y.Z`. iOS and macOS now fetch their own
  `Wat is er nieuw` notes so an iOS app can no longer show macOS release notes.

### Tests

- Added coverage for first-install versus upgraded-version `Wat is er nieuw`
  behavior.
- Added coverage for platform-specific public release tags and encoded release
  note URLs.

## 3.1.18 - 2026-06-13

### Changed

- Scoped Bonjour/mDNS `_djconnect._tcp` advertising to the pairable state. The
  app advertises while unpaired/pairing, keeps the local HTTP API alive after
  pairing, and stops Bonjour publication to reduce network and battery impact.
- Improved iOS/macOS battery behavior by pausing wakeword listening and local
  progress timers outside the foreground, throttling automatic resume/startup
  refreshes, and reducing background collection refresh churn.
- Added a shared 24-hour artwork data cache for Now Playing, queue, playlists,
  and dominant artwork tint sampling to reduce repeated downloads and decode
  work while scrolling.
- Matched playlist rows to the queue row style with dark purple gradient
  cards, consistent padding, artwork, and play/loading indicators.
- Polished Maze Chase visuals with a directional player mouth and ghost eyes,
  and slowed the ghost movement so the game is more approachable.

### Tests

- Added coverage for Bonjour advertising preference across unpaired, Demo Mode,
  and paired app states.

## 3.1.16 - 2026-06-13

### Changed

- Removed the non-functional local `iPhone standaard` and `Mac standaard`
  output choices. The selector now starts with `Geen`/`None` followed only by
  real Home Assistant backend devices.
- Polished iOS/macOS Logs, Settings, About, Queue, and Playlists styling so
  actions use the DJConnect purple accent, logs render on the gradient canvas,
  and queue rows use a subtle dark purple background.
- Updated the splash and launch banner copy to use `Muziekbediening met
  karakter.` consistently and keep the DJConnect title centered.
- iOS now schedules a full playback refresh when the app returns to the
  foreground.
- Log level choices are ordered from most verbose to least verbose:
  Debug, Info, Warning/Waarschuwing, Error/Fout.

### Fixed

- Mapped Home Assistant `Player command failed. No active device found` errors
  to a localized user-facing message instead of exposing the raw backend text.
- Improved the macOS Logs screen so mouse/trackpad scrolling works reliably and
  scrollbars remain visible.
- Kept copy/value rows readable by rendering user-facing values in white while
  retaining purple action icons.

### Tests

- Updated output-device tests for the new `Geen` plus real-devices model.
- Added regression coverage for localized no-active-device DJ response errors.

## 3.1.15 - 2026-06-12

### Changed

- Refined iOS/macOS Now Playing so the connection card sits below the album
  art/playback controls and above the output selector.
- Replaced remaining system-blue action accents with the DJConnect purple
  accent for copy buttons, website links, output/volume controls, logs, and
  selected navigation states.
- Added elapsed/total time below the current-track progress slider.
- Improved queue and playlist row loading states with larger inline spinners.

### Fixed

- Backend-unavailable playback now shows a red playback-status dot while the
  Home Assistant pairing state can remain correctly marked as connected.
- Spotify authorization recovery now clears the stale DJ request warning and
  restores the default microphone instruction once playback/backend status is
  healthy again.
- Logs clearing now asks for confirmation before removing visible and persisted
  diagnostics.
- Updated Dutch voice fallback copy from DJ announcements to DJ requests.

### Documentation

- Updated README, API contract, handoff, and sync prompts for backend recovery
  UX, queue limit 100, nullable empty playback snapshots, and rolling logs.

## 3.1.14 - 2026-06-12

### Added

- Added a dedicated Logs screen on iOS and macOS and moved runtime logs out of
  Settings.
- Added redacted rolling diagnostic file logging in Application Support so Logs
  can survive app restarts and crashes.
- Added Pac-Man to the local Games menu alongside Pong, Asteroids, and Fly.
- Added local output defaults (`Geen` and the platform default output) before
  Home Assistant playback devices.

### Changed

- Queue requests now send `limit:100`; README, API contract, handoff, release
  docs, and canonical sync prompts are aligned for Home Assistant support.
- Improved macOS navigation by exposing More-menu screens directly in the
  sidebar and letting content extend into the titlebar area.
- Improved Settings rows, empty Queue layout, playlist/queue artwork sizing,
  and backend-unavailable messaging.

### Fixed

- Prevented empty queues from rendering duplicate placeholder rows.
- Improved output selection handling for synthetic local/default outputs.
- Expanded unit coverage for queue limit and output default behavior.

## 3.1.12 - 2026-06-11

### Fixed

- Avoided the unstable iOS/macOS speech-recognition permission prompt that
  could crash when requesting permissions from Settings. If speech access is
  already granted the app accepts it; otherwise it logs a friendly unavailable
  state instead of invoking the crash-prone system prompt.
- Added a non-destructive `--monkey-testing` launch mode for automated UI
  stress tests. It starts in local Demo Mode, hides blocking first-run/pairing
  prompts, and avoids local API/backend traffic.
- Lazy-started local Games behind a "Tap to play" overlay so first navigation
  to the Games screen no longer starts Pong immediately. Leaving Games resets
  all games back to the overlay state. Pong now keeps the center line visible
  while hiding the ball until play starts.
- Added "Muziekbediening met karakter." to the splash screen, kept the spinner
  below it, and kept the launch storyboard compatible with Apple's launch
  screen restrictions.
- Removed the album-art border treatment and let macOS content extend into the
  titlebar area so the DJConnect canvas no longer stops below a separate strip.
- Replaced deprecated macOS demo speech playback with `AVSpeechSynthesizer` and
  imported Combine explicitly for the local game timer publisher.
- Improved accessibility labels for icon-only playback controls and enlarged
  previous/next, seek, shuffle, and repeat controls. Active shuffle/repeat now
  use purple, and seek buttons render white.
- Made queue/playlist start toasts stand out with a brighter accent gradient
  against the DJConnect dark canvas.
- Added iOS and macOS UI monkey-smoke coverage for non-destructive navigation
  through Now Playing, Queue, Playlists, Games, Settings, and About.
- Added Dutch app localization resources so iOS system UI such as the overflow
  tab can localize to "Meer".
- Kept release metadata, handoff, API examples, and sync prompts aligned with
  app/protocol version `3.1.12`.

## 3.1.11 - 2026-06-11

### Fixed

- Added DEBUG logging around each permission request step and callback to
  diagnose iOS/macOS permission crashes.
- Routed permission callbacks back through the MainActor before resuming the
  request flow.
- Added the iOS native launch-screen spinner under the DJConnect title.
- Applied the DJConnect gradient canvas to Now Playing and the pairing sheet.
- Added consistent subtle rounded borders to album artwork on Now Playing,
  queue, and playlist rows.
- Updated Demo Mode DJ request copy and Dutch Settings translations for
  push-to-talk, stemactivatie, and wake-word labels.

### Documentation

- Added App Store and Mac App Store submission metadata, required labels,
  descriptions, privacy labels, permissions copy, and review notes.

## 3.1.10 - 2026-06-11

### Added

- Added a local Games menu on iOS and macOS with Pong, Asteroids and Fly,
  including local highscores, touch/click controls, and keyboard arrow handling
  that stays inside the game surface.
- Added a startup spinner to the branded launch overlay.
- Added a local Demo Mode DJ announcement response with spoken audio and
  visible text for App Store review without Home Assistant.

### Documentation

- Updated the App Store/macOS release checklist for renewed Apple Developer
  Program accounts and clarified the local signed/notarized public macOS
  release path.
- Updated README, handoff, architecture, development, API contract, release,
  TODO, and issues documentation for the local iOS/macOS Games menu, Demo Mode,
  permission handling, default Home Assistant URL, and iOS/macOS visual polish.

### Tests

- Added iOS UI-test coverage for the Games tab and local Pong, Asteroids, and
  Fly choices.

### Changed

- Applied the DJConnect blue/purple gradient canvas consistently across iOS
  runtime screens.
- Compact permission rows on iPhone and removed the fake Local Network
  preflight action; Local Network remains declared and is requested by iOS when
  the app actually touches the LAN.
- Changed Dutch Demo Mode page titles to use `(demo)`.
- Defaulted the Home Assistant URL field to `http://homeassistant.local:8123`
  on fresh installs.
- Updated Dutch pairing, voice, and wakeword labels, including
  `Koppelcode`, `Koppelgegevens voor Home Assistant:`, and
  `Stemactivatie inschakelen/uitschakelen`.

## 3.1.9 - 2026-06-11

### Added

- Added iOS/macOS current-track seek controls that send `seek_relative` commands
  to Home Assistant with millisecond offsets.
- Added iPhone haptic feedback for push-to-talk, playback controls, queue and
  playlist starts, output selection, volume commits, and received DJ responses.
- Added a blocking update-required sheet when the app detects an incompatible
  Home Assistant integration protocol version.

### Fixed

- Avoided a macOS startup crash in the launch container by passing the root view
  as built content instead of executing a `@ViewBuilder` closure inside the
  container initializer.
- Fixed permission-request callbacks so microphone/speech authorization returns
  through the main queue before updating SwiftUI state.
- Made the macOS pairing-sheet Quit App action call the AppKit terminate action
  directly.

### Changed

- Reworked the main canvas background into full-screen multi-corner fading
  gradients without visible rectangular blocks.
- Updated the pairing/about/settings polish: Demo Mode appears in screen titles,
  About is compact on macOS, technical Client/Platform rows were removed, Device
  ID no longer shows a copy button in About, and the DJConnect banner uses
  consistent rounded corners.
- Default app language now follows the device language on first launch.
- Renamed Dutch wakeword settings labels to Stemactivatie.
- Disabled all refresh affordances in Demo Mode and changed refresh buttons to
  show spinners while their specific load action is running.

### Documentation

- Consolidated sync prompts to the canonical source
  `pcvantol/djconnect/SYNC_PROMPTS.md` and removed obsolete local copies.
- Moved the canonical product roadmap policy to
  `pcvantol/djconnect/PRODUCT_ROADMAP.md`; this repo no longer keeps a local
  roadmap copy.
- Updated app/protocol examples to `3.1.9`.

## 3.1.8 - 2026-06-11

### Added

- Added private GitHub Actions CI for Swift tests and unsigned iOS/macOS build
  checks.
- Added a local signed/notarized macOS release helper that uploads zip and
  checksum assets to the public `pcvantol/djconnect-app-releases` repository.

### Changed

- Protected newly saved DJConnect bearer tokens with Keychain user-presence
  access control, enabling Touch ID on supported Macs and Face ID/Touch ID on
  supported iOS devices with platform password fallback.
- Removed duplicate welcome-screen title/subtitle below the DJConnect banner.
- Localized the welcome-screen Home Assistant setup line in Dutch.
- Changed the welcome-screen setup link to `https://djconnect.dev/start`.
- Added a macOS-only quit option to the blocking pairing sheet.
- Moved the pairing code above the Client adres on the pairing sheet.
- Added a Keychain access recovery sheet when token access is denied.
- Cached a successfully unlocked Keychain token in memory for the app session
  to avoid repeated system prompts.
- Added trailing play affordances to playlist rows on iOS and macOS.
- Changed the About website row to open the DJConnect website directly.
- Moved legal and OSS notices behind a Notice popover and removed redundant
  About rows.
- Removed Voice and Local Response Audio settings rows because those are now
  standard app behavior.
- Removed redundant Client and Local URL rows from Settings.
- Hid pairing code/actions in Settings while Demo Mode is active.
- Returning from Demo Mode or resetting pairing now navigates back to Now
  Playing behind the pairing sheet.
- Improved the macOS Quit App button on the pairing sheet so it is focusable and
  behaves like a normal button.
- Clarified wakeword status in Demo Mode.
- Added DEBUG logging for user actions/navigation flows, Home Assistant API
  calls, and local Client API calls with HTTP status codes and without tokens.
- Added queue and playlist start status toasts that auto-dismiss.
- Hid Demo Mode setup status from Now Playing and clarified DJ request demo
  copy.
- Added a DJConnect blue/purple canvas background with glass-friendly depth.
- Suppressed the possible-crash prompt while running under a debugger, reducing
  false positives after stopping from Xcode.
- Demo Mode now shows the DJConnect app icon as fallback Now Playing artwork.
- Wakeword remains disabled in Demo Mode to avoid starting real Speech/audio
  capture from sample state.
- Demo Mode is now session-only and resets on app restart, so unpaired clients
  always return to the pairing sheet.
- Set app/protocol version to `3.1.8`.

### Documentation

- Updated README, development, release, handoff, architecture, sync prompts,
  TODO, and issues documentation for the 3.1.8 pairing sheet, Demo Mode,
  Client adres stability, About website, Xcode 26.5 verification, and
  security-hardening backlog.

## 3.1.7 - 2026-06-11

### Added

- Added a blocking pairing sheet for unpaired clients with the DJConnect banner,
  copyable Client adres, copyable pairing code, and pairing status/progress.
- Added a post-pairing success state with a large green checkmark and a
  prominent "Let's Start!" action before releasing the main UI.
- Added a demo mode from the pairing sheet so App Store review/auditing can
  inspect playback, queue, playlists, output, and voice UI without a live Home
  Assistant backend.
- Added the DJConnect website `https://djconnect.dev` to the About page.

### Changed

- Set app/protocol version to `3.1.7`.
- Delayed the wakeword activation prompt until after the user closes the
  pairing success sheet.

## 3.1.6 - 2026-06-11

### Added

- Added one-time first-install onboarding with DJConnect branding, setup link
  to `pcvantol/djconnect`, and a Spotify Premium requirement notice.
- Added user-mediated crash reporting after suspected unclean exits: users can
  copy redacted diagnostics or open a prefilled GitHub issue. The app never
  uploads logs automatically.
- Added Home Assistant integration version gating: app `3.1.x` accepts HA
  `3.1.x` only (`>=3.1.0`, `<3.2.0`) and disables playback/output/queue/
  playlist/liked/voice controls while Settings and pairing reset remain
  available.
- Added Settings permission status/preflight UI for Microphone, Speech
  Recognition, and Local Network.
- Added foreground wakeword support with a configurable wake phrase, defaulting
  to "Hey DJ", using Apple Speech while the app is open. Wakeword is
  session-only, does not auto-start after launch, and is disabled on iOS
  Simulator because simulator speech/audio capture is unstable.
- Added a post-pairing wakeword activation prompt when wakeword is still off,
  with explicit activate and not-now actions.
- Added local playback for returned DJ response audio URLs when local response
  audio is enabled.
- Added a local backlog in `docs/ISSUES.md` with priorities and acceptance
  criteria for performance, testing, release validation, and platform polish.

### Changed

- Set app/protocol version to `3.1.6`.
- Consolidated README, handoff, sync prompts, release notes, architecture docs,
  TODO, and issues documentation around onboarding, Spotify Premium, crash
  reporting, version gating, permissions, release validation, and performance
  follow-ups.
- Tightened app-client identity and pairing behavior for iOS/macOS: use
  `device_id` plus `client_type`, keep app-generated pairing codes stable
  during mismatch recovery, persist `ha_local_url`, and keep cloud URLs out of
  app-to-HA runtime traffic.
- Kept the Client adres used during pairing stable until explicit pairing
  reset so Home Assistant can continue calling the same local app endpoint
  after restarts.
- Expanded the local `/api/device/*` Apple app API for Home Assistant -> app
  traffic, including info, pairing-info, pair, command, DJ response, and forget
  routes.
- Improved Now Playing, Queue, Playlists, Settings, Logs, and About UI across
  iOS, iPadOS, and macOS, including iPad launch/hero layout, app banner usage,
  copyable pairing/API details, clearer Dutch labels, better log naming, and
  macOS sizing/icon behavior.
- Reworked playback UX: output selection lives on Now Playing, playlist flows
  have their own page, liked songs use the same row style, shuffle/repeat use
  consistent icon buttons, and transport icons now use previous-track/
  next-track semantics.
- Improved refresh behavior for startup, pairing completion, manual refresh,
  play/pause/next/previous, queue item selection, volume commits, and voice
  responses so Now Playing, album art, output, queue, playlists, and progress
  recover more reliably after Home Assistant/Spotify settle.
- Updated queue handling to the Home Assistant `queue.items` contract with
  context preservation, album-art aliases, duplicate-row-safe SwiftUI
  identities, `play_context_at` playback, and Spotify offset safeguards for
  contexts that do not support offsets.
- Improved voice/PTT behavior with true press-to-hold recording, listening/
  processing states, friendly STT/OAuth error mapping, JSON server-message
  extraction, and relative audio URL resolution against the HA local URL.
- Improved diagnostics/logging by redacting server error bodies, keeping
  technical voice/backend details in logs instead of UI, shortening log level
  labels to `INF`, `DBG`, `WRN`, and `ERR`, and keeping logs pinned to the
  newest entry.
- Refined app architecture/documentation around permission boundaries,
  user-mediated crash reporting, current version contract, release cleanup, and
  future performance work.

### Fixed

- Fixed iPadOS simulator microphone permission crashes by using the iOS 17+
  recording-permission API and returning permission callbacks to the MainActor.
- Fixed manual refresh clearing album art when sparse status payloads were
  returned by loading rich Now Playing snapshots first.
- Fixed queue item playback attempts that used unsupported HA commands by
  switching to supported context-based playback.
- Fixed Now Playing album art layout so artwork remains square and cannot push
  title/artist text off screen.
- Fixed volume slider state when top-level playback volume is missing by using
  active playback-device volume.
- Fixed raw JSON and technical backend errors appearing in the DJ announcement
  card by extracting friendly messages and logging the technical details.

## 3.1.4 - 2026-06-11

### Added

- Added an initial `DJConnectIOSUITests` target with deterministic
  `--uitesting` launch mode, isolated defaults, in-memory token storage, mock
  Home Assistant URL seeding, and coverage for primary iOS navigation and
  Settings URL wiring.
- Added iOS release/signing documentation covering Apple Developer Program
  requirements, bundle identifiers, signing team setup, device testing,
  archives, and TestFlight upload prerequisites.

### Changed

- Set app/protocol version to `3.1.4`.
- Persisted Speech Recognition usage descriptions in `project.yml` so wakeword
  permissions survive Xcode project regeneration.
- Increased the default and minimum macOS main window size so the sidebar/menu
  layout has more room by default.

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
  through `/api/djconnect/v1/command`.
- Added Push-to-Talk recording with mono PCM WAV upload to
  `/api/djconnect/v1/voice`.
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
