# DJConnect App

DJConnect. Muziekbediening met karakter.

This repository contains native iOS, macOS, and watchOS DJConnect clients that
talk to the Home Assistant `djconnect` custom integration. Home Assistant stays the
trusted backend for pairing, DJConnect bearer-token lifecycle, Spotify OAuth,
playback commands, Assist/STT/TTS, and native HA entities.

The app owns native UI, local app state, local bonus games, optional local voice
recording, and optional playback of returned DJ response audio. It must not
store Spotify, Home Assistant, Sonos, OpenAI, or other backend credentials. The
only app-owned credential is the DJConnect client bearer token issued by the
integration.

Ask DJ is the Apple clients' rich DJ interaction surface on iOS, macOS, and
watchOS. Text chat, push-to-talk voice requests, replayable DJ response audio,
images, links, sources, synced history, Play Now recommendation actions, and
speaker/output action rows live there; Now Playing no longer has a separate DJ
request block. Home Assistant owns Ask DJ intent interpretation,
follow-up/confirmation state, morning-start context, output switching, and
playback execution; Apple clients render the returned messages, media, and
actions. Ask DJ message and command payloads include `device_id`,
`device_name`, `client_id`, and `client_type`; action taps send the
backend-returned action object back where possible so Home Assistant keeps
ownership of follow-up and output metadata.
Ask DJ also carries the current client mood as structured `mood` metadata when
available. Assistant answers may return their own `mood` / `mood_context`;
clients use that structured value, or the current selected client mood as a
fallback, to tint assistant bubbles consistently with Track Insight mood zones.
Clients never infer generated/fallback state or mood by parsing visible answer
text.

AI and Assist answers can be incorrect and depend on your own Home Assistant
and Assist configuration.

Website: [https://djconnect.dev](https://djconnect.dev)

## Documentation

- [docs/HANDOFF.md](docs/HANDOFF.md): original product and integration handoff.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): repository architecture and target responsibilities.
- [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md): key decisions and rationale.
- [docs/TECHNICAL_DESIGN_DECISIONS.md](docs/TECHNICAL_DESIGN_DECISIONS.md):
  reverse-engineered code-level design patterns, coding conventions, and dependency inventory.
- [docs/API_CONTRACT.md](docs/API_CONTRACT.md): Home Assistant endpoint contract.
- [DEVELOPMENT_ENVIRONMENT.md](DEVELOPMENT_ENVIRONMENT.md): local machine,
  toolchain, simulator, signing, and hygiene setup.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): local development, generation, build, and test commands.
- [docs/RELEASE.md](docs/RELEASE.md): signing, TestFlight, notarization, and live HA validation checklist.
- `pcvantol/djconnect/SYNC_PROMPTS.md`: canonical source for cross-repo DJConnect
  sync prompts and contract instructions.
- `pcvantol/djconnect/PRODUCT_ROADMAP.md`: canonical DJConnect product roadmap.
- [docs/TODO.md](docs/TODO.md): open work, known issues, and next implementation steps.
- [docs/ISSUES.md](docs/ISSUES.md): concrete local backlog with priorities and acceptance criteria.
- [PRIVACY.md](PRIVACY.md): security, privacy, and diagnostics redaction rules.
- [SECURITY.md](SECURITY.md): private vulnerability reporting via security@djconnect.dev.
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md): community standards and reporting guidance.
- [CHANGELOG.md](CHANGELOG.md): notable project changes.
- [LICENSE](LICENSE): MIT license for the DJConnect app source.

## First Run Requirements

On first launch the app shows a one-time DJConnect welcome screen with the
Home Assistant setup link:

- [https://djconnect.dev/start](https://djconnect.dev/start)

DJConnect playback requires a configured Home Assistant `djconnect`
integration and a supported HA-side music backend. The app does not ask for
Spotify or Music Assistant credentials; backend credentials stay owned by Home
Assistant.

If the app is not paired yet, the main runtime UI is blocked by a pairing
sheet. On iOS/macOS that sheet asks for the local Home Assistant address and
pairing code/QR. Apple Watch pairing starts on the paired iPhone by scanning
the Home Assistant-generated Apple Watch QR/deep-link with
`client_type=watchos`; the iPhone proxy still posts the pairing request with
the Watch identity. The Watch only shows companion status and never asks for a
Home Assistant URL or code. After Home Assistant completes pairing, the sheet
shows a success state before the runtime UI is released.

Pairing is always LAN-first and local-only. Use `http://homeassistant.local:8123`
or the Home Assistant LAN IP address while the Apple device is on the same
Wi-Fi/LAN. Remote Home Assistant URLs are accepted only from the successful
pairing response and are used later as fallback for runtime status/playback
traffic when local access is unavailable.

For App Store review and local UI inspection, the pairing sheet also exposes
Demo Mode. Demo Mode fills Now Playing, queue, playlists, and DJ announcement
UI with local sample data without contacting Home Assistant.
It is session-only, resets on app restart, and is not a replacement for live
backend validation. Pressing the microphone in Demo Mode shows and speaks a
local sample DJ announcement so App Store review can inspect the voice response
experience without a Home Assistant backend.

The app also includes local Games with Paddle Rally, Meteor Run, Sky Dash, and
Maze Chase, mirroring the ESP client bonus games. Games are local-only, store
highscores in app-local
preferences, and do not call Home Assistant or create HA entities. Games lazy
start behind a tap-to-play overlay, and leaving the Games screen resets them
back to that idle state. When a game surface has keyboard focus, arrow keys and
space are consumed by the game and must not trigger app navigation. On iPad
landscape, the game canvas is height-capped so the movement/action buttons stay
visible below the playfield.

Debug and UI stress runs can launch with `--monkey-testing`. This starts a
non-destructive local Demo Mode, hides first-run/pairing blockers, avoids local
API/backend traffic, and is safe for random navigation/tap monkey tests.

Fresh installs default the Home Assistant URL field to
`http://homeassistant.local:8123`. Users can replace it with an IP-based local
URL when multicast DNS is unavailable.

## Package Shape

```text
DJConnectApp.xcodeproj
project.yml
Apps/
  DJConnectIOS/
  DJConnectMac/
  DJConnectWatch/
docs/
Sources/
  DJConnectCore/
    DJConnectClient.swift
    DJConnectErrors.swift
    DJConnectKeychain.swift  # token-store abstraction; retained filename
    DJConnectModels.swift
Tests/
  DJConnectCoreTests/
```

`DJConnectCore` is intentionally UI-free. It handles:

- stable client identity payloads with `client_type` set to `ios`, `macos`, or
  `watchos`;
- authenticated Home Assistant requests;
- opt-in local Home Assistant native `/api/websocket` fast-path transport for
  latency-sensitive DJConnect actions after separate Home Assistant WebSocket
  auth succeeds;
- status, command, and raw WAV voice request serialization;
- playback and voice response decoding;
- error classification for auth stale, backend unavailable, version mismatch,
  missing routes, and network failures;
- token storage through a small abstraction backed by app-private storage.

`DJConnectUI` contains the shared native SwiftUI screens used by the iOS and
macOS app targets. `Apps/DJConnectIOS`, `Apps/DJConnectMac`, and
`Apps/DJConnectWatch` contain the platform app entrypoints. The Watch app is a
companion-only watchOS client with its own compact SwiftUI surface, app-local
UI cache, playback controls, and push-to-talk voice capture through the
`Ask DJ` action. HA pairing, bearer token ownership, APNs registration, remote
fallback, status refresh, history sync, playback actions, and voice upload are
mediated by the paired iPhone over WatchConnectivity. The Watch does not store
`ha_remote_url`, does not choose Home Assistant transport, does not host a local
inbound Web API. The Watch still reports
`client_type:"watchos"` metadata through the iPhone proxy. Foreground wake
phrase support may be added later, but the Watch target must not promise
always-on background wakeword listening.

Music DNA is first-class on iOS, macOS, and watchOS. The profile remains
server-side in Home Assistant and is explicit opt-in. iOS/macOS call the Music
DNA endpoints directly; watchOS uses the paired iPhone proxy while preserving
the Watch `device_id` and `client_type:"watchos"`. The initial Music DNA consent
sheet can be reached from Ask DJ or from the Music DNA screen, and Watch
Settings can turn Music DNA off or on again. Turning it off clears learned Music
DNA on the backend and stops further buildup until it is enabled again. The
Settings explanation is contextual: when Music DNA is disabled, clients explain
that no profile is being built and that the learned profile has already been
cleared. The separate clear-profile action is shown only while Music DNA is
enabled, because opting out already clears the learned profile. After opt-in or
opt-out, clients may temporarily keep the just-selected enabled state visible
while a stale profile refresh catches up; Home Assistant remains authoritative
once it returns the matching state.

iOS and macOS can export and import Music DNA backups from Settings. Export is
an authenticated HTTP `POST /api/djconnect/v1/music_dna/export` call and saves the
exact server-built JSON envelope through the native share/save panel; clients do
not reconstruct exports from cached profile data and do not add tokens,
bootstrap proofs, raw prompts, raw audio, diagnostics, or local cache fields.
Import previews a selected JSON backup locally, then uploads it to Home
Assistant only while paired and connected.

Ontdek / Discover is the iOS/macOS Music Discovery surface and is also available
as a compact Apple Watch list/detail flow. It appears directly after Track
Insight in primary navigation on iOS/macOS and lets watchOS users open a
recommendation to read the backend reason before tapping Play Now. It is backed
only by Home Assistant Music DNA data. The client loads
`GET /api/djconnect/v1/music_discovery`, refreshes
with `POST /api/djconnect/v1/music_discovery/refresh`, and plays accepted items via
`POST /api/djconnect/v1/music_discovery/play` so Home Assistant can record the
acceptance as a positive Music DNA signal. Clients must not generate
recommendations or reasons locally, and displayed items require a backend `id`,
`kind`, `title`, playable `uri`, and `reason`. If Music DNA is disabled, Ontdek
shows the opt-in/locked state instead of an empty grid. Load failures stay in
the app model and refresh controls instead of replacing the page with an error
card. On iOS the Home Screen
quick action `dev.djconnect.action.discovery` and deep links
`djconnect://discover` / `djconnect://ontdek` / `djconnect://music-discovery`
jump directly to Ontdek.
The Discover/Ontdek Play Now action uses the same native start-feedback model as
other playback-start actions, while Track Insight analysis/open actions stay
visually rich but do not add extra haptic feedback.

Home Assistant may send the daily APNs reminder event `music_discovery_ready`
with notification body `Je nieuwe aanbevelingen staan klaar!`, open target
`music_discovery`, refresh target `music_discovery`, and deeplink
`djconnect://music-discovery`. iOS and macOS show the notification, and receiving
or tapping it refreshes Ontdek through the websocket fast path
`djconnect/music_discovery/refresh` when Home Assistant advertises it. If the
fast path is unavailable, the clients use
`POST /api/djconnect/v1/music_discovery/refresh`; if refresh is rate-limited or
temporarily unavailable, they fall back to `GET /api/djconnect/v1/music_discovery`.
Recommendation titles, artwork, sections, and reasons are rendered only from the
backend response `sections[].items[]`, never from the push payload itself.

Mood is a user-selected app and recommendation context. Apple clients default to
the neutral midpoint (`50`) after install, map Mood to the four zones
`0...24 = chill`, `25...59 = groove`, `60...84 = energy`, and `85...100 = party`,
and pass the numeric value to Ask DJ, playback commands, Music DNA, and Music
Discovery requests where supported. The selected Mood also drives visual accents
for Now Playing, Queue, Ask DJ, Track Insight, VibeCast, and widgets. Track
Insight uses the same floating Mood control pattern as Ask DJ. Mood changes and
intentional playback/Ask DJ actions use native haptic feedback on iOS/watchOS
and supported macOS hardware; watchOS demo mode keeps haptics enabled on real
hardware.

APNs push registration is supported for iOS, macOS, and watchOS clients. iOS
uses `client_type: "ios"` and `device_id` values shaped like
`djconnect-ios-XXXXXXXXXXXX`; macOS and watchOS use their own matching prefixes.
The watchOS client uses its own stable Watch install ID and sends the Watch
APNs token to HA through the paired iPhone as `client_type: "watchos"`, never
the companion iPhone identity.
The app registers with Home Assistant after APNs returns a token and Home
Assistant auth is available, and retries when the token fingerprint, APNs
environment, bundle ID, app version, locale, or pairing target changes. Debug
logs must stay privacy-safe: do not print bearer tokens, APNs tokens,
`bootstrap_proof` values, or central `djci_` install tokens.

## Xcode

Open [DJConnectApp.xcodeproj](DJConnectApp.xcodeproj) in Xcode.

Schemes:

- `DJConnectIOS`: native iOS app target.
- `DJConnectMac`: native macOS app target.
- `DJConnectWatch`: native companion-only watchOS app target.

The project is generated from [project.yml](project.yml) with XcodeGen:

```sh
xcodegen generate
```

Build checks used for this scaffold:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectWatch -destination generic/platform=watchOS CODE_SIGNING_ALLOWED=NO build
```

The latest verification was performed with Xcode 26.5 (`17F42`) against
macOS 26.5, iPhoneOS 26.5, and WatchOS 26.5 SDKs, with code signing disabled
for local build checks.

The public GitHub repository has secret scanning, push protection, Dependabot
alerts/security updates, and branch protection enabled for `main`. Required
status checks must be green before protected-branch changes are merged or
pushed without an explicit maintainer bypass.

Private GitHub Actions CI runs Swift tests plus unsigned iOS/macOS build
checks. Release tags also publish unsigned macOS and iOS diagnostic artifacts
to [pcvantol/djconnect-app-releases](https://github.com/pcvantol/djconnect-app-releases)
when the private repo has a `PUBLIC_RELEASES_TOKEN` secret with write access to
that public repository. The public unsigned releases are platform-specific:
`macos/vX.Y.Z` contains the unsigned macOS artifact and macOS release notes,
while `ios/vX.Y.Z` contains the unsigned iOS artifact and iOS release notes.
Public macOS binaries for end users are still produced locally with Developer ID
signing and notarization, then uploaded to the same public releases repository.
Use the one-time and per-release App Store/macOS checklist in
[docs/RELEASE.md](docs/RELEASE.md) before publishing signed builds.
If the public unsigned workflow fails before its website publication step,
static What's New files on `djconnect.dev` may be missing even when the source
GitHub release exists; verify the live release-note JSON URLs for each shipped
version.

On startup after an app update, DJConnect compares the running version with the
last version seen on that device. If the version changed, the app shows a
`Wat is er nieuw` / `What's New` sheet and loads the current release notes from
static files on `djconnect.dev`. The app tries the selected language first,
for example `/release-notes/ios/nl/vX.Y.Z.json`,
`/release-notes/macos/de/vX.Y.Z.json`, or
`/release-notes/ios/es/vX.Y.Z.json`. Supported static What's New languages are
`en`, `nl`, `de`, `fr`, and `es`; unsupported languages fall back to English,
then the older platform-only JSON path and finally the GitHub release metadata
API.

## Swift Package

The reusable core and UI modules also compile as a Swift Package:

```sh
swift test
```

## Integration Contract

Status is posted to:

```http
POST /api/djconnect/v1/status
```

Playback commands are posted to:

```http
POST /api/djconnect/v1/command
```

Voice/PTT WAV audio, when implemented by an app target, is posted to:

```http
POST /api/djconnect/v1/voice
Content-Type: audio/wav
```

Home Assistant owns STT, Assist, intent parsing, Spotify status/commands, and
DJ response generation. The app does not need Spotify credentials or local
Spotify Web API calls for voice commands. Canonical examples from
`pcvantol/djconnect/examples/voice_intents.json` include:

| Family | NL examples | EN examples | Client behavior |
| --- | --- | --- | --- |
| `current_track` | `Welk nummer draait er nu?`, `Welk nummer speelt er nu?`, `Wat draait er?`, `Wat speelt er?`, `Wat is dit?` | `What song is playing?`, `What track is playing now?`, `What's playing?`, `Which song is this?` | Upload voice audio; HA reads current playback state and returns a DJ response without starting playback. |
| `playback_control` | `Stop muziek`, `Start muziek`, `Zet harder`, `Zet zachter`, `Volgende nummer`, `Vorig nummer` | `Stop music`, `Start music`, `Turn it up`, `Turn it down`, `Next song`, `Previous song` | Upload voice audio; HA maps the phrase to backend playback commands such as `pause`, `play`, `set_volume`, `next`, or `previous`. |
| `favorite_current_track` | `Voeg dit nummer toe aan mijn favorieten`, `like dit nummer`, `sla deze track op` | `Add this song to my favorites`, `like this track`, `save this song` | HA likes/saves the current playback item and returns a DJ confirmation. |
| `output_devices_info` / `current_output_info` | `Welke speakers zijn er?`, `Waarop wordt nu muziek gespeeld?`, `Op welke speaker speelt dit?` | `Which speakers are available?`, `Where is music playing now?`, `Which speaker is active?` | HA reads DJConnect output devices/current playback output and returns an informational DJ response without changing playback. |
| `personalized_mood_playback` | `Ik voel me moe en geprikkeld, zet wat rustige muziek op die ik fijn vind`, `Doe iets ontspannends, ik ben overprikkeld` | `I am tired and overstimulated, play relaxing music I will enjoy`, `play something calming that I usually like` | HA combines the mood request with Music DNA/user preferences and starts or queues a suitable playback context. |
| `change_music_context` | `Ik wil wat anders horen`, `Doe maar iets anders`, `Zet iets heel anders op` | `I want to hear something else`, `play something different`, `put on something completely different` | HA treats this as a playback-changing request, picks a different suitable track/album/playlist from current playback context and user taste, and starts or queues it. |
| `personal_music_profile_analysis` | `Omschrijf eens waar ik zoal naar luisterde de afgelopen maand`, `Wat zegt mijn muziek van de laatste twee weken over mijn stemming?` | `Describe what I have been listening to over the last month`, `what does my music from the last two weeks say about my mood?` | HA summarizes listening patterns, genres, moods, energy, artists, and taste shifts from Music DNA for the requested period without changing playback. |
| `personal_music_recommendations` | `Geef me muziek aanbevelingen op basis van mijn luisterprofiel`, `Wat zou ik nu leuk vinden om te luisteren?`, `Raad me iets nieuws aan dat past bij mijn smaak` | `Recommend music based on my listening profile`, `what should I listen to now?`, `recommend something new that fits my taste` | HA recommends concrete tracks, albums, artists, or playlists from Music DNA and Spotify profile data without changing playback unless the user explicitly asks to play or queue them. |
| `dj_announcement_request` | `Geef me een leuke aankondiging voor het volgende nummer`, `Doe een radio intro voor wat er nu speelt` | `Give me a fun announcement for the next song`, `do a radio-style intro for what is playing now` | HA generates DJ text and optional `audio_url` without changing playback. |
| `track_context_info` | `Vertel iets over dit nummer`, `Wanneer kwam dit uit?`, `Waarom koos je dit nummer?`, `Heeft deze artiest concerten in Nederland?` | `Tell me about this song`, `what year was this released?`, `why did you choose this track?` | HA enriches current playback with release, genre, commentary, trivia, samples, concerts, releases, and musical connections without changing playback. |
| `track_insight` | `Geef Track Insight voor dit nummer`, `Analyseer deze track`, `Hoe is deze track opgebouwd?`, `Welke instrumenten hoor je hierin?` | `Give me Track Insight for this song`, `How is this track built up?`, `Why does this track work so well?` | HA gives a read-only Track Insight of the current track, focused on energy, arrangement, instrumentation, production and musical commentary without changing playback. Direct Track Insight requests include the canonical `client_type`. |

Ask DJ output-device responses may include structured output `playback_actions`.
Apple clients render those vertically, with the speaker name on the left and an
`Actief`/`Activeer` button on the right. Opening Ask DJ scrolls the synced chat
history to the newest message by default, including after the first async
history load. Clearing Ask DJ history calls
`POST /api/djconnect/v1/ask_dj/history/clear`; the returned `clear_revision` is
the authoritative full-clear signal for local cached history.

The native app also uses command proxy flows for backend devices, queue,
playlists, liked songs, and output selection:

```http
POST /api/djconnect/v1/command
{"command":"devices"}
{"command":"queue"}
{"command":"playlists"}
{"command":"seek_relative","value":15000}
{"command":"seek_relative","value":-15000}
{"command":"set_output","value":"<device id or name>"}
{"command":"start_playlist","value":"spotify:playlist:...","play":true}
{"command":"play_context_at","value":{"context_uri":"spotify:playlist:...","offset_uri":"spotify:track:..."},"play":true}
{"command":"start_liked_proxy","play":true}
```

Queue item playback includes `offset_uri` only for Spotify contexts that support
offsets, such as playlist, album and show contexts. Artist contexts are sent
without `offset_uri` to avoid Spotify API offset errors.

Spotify source and liked/default playlist overrides are not client settings.
Setup, Settings, onboarding, and command payloads must not expose or send
`spotify_source` or `liked_proxy_playlist_uri`; playback remains mediated by
the Home Assistant DJConnect integration through generic commands.

The iOS/macOS/watchOS app can expose seek controls for the current track. It sends
`command:"seek_relative"` with `value` in milliseconds. Positive values seek
forward, negative values seek backward. This is an Apple-app-only UI affordance;
ESP clients may omit it.

The output selector shows a local `Geen`/`None` option followed by real backend
devices returned by Home Assistant. The app does not add local `iPhone
standaard` or `Mac standaard` choices. Selecting `Geen` blocks playback-start
commands until the user chooses a real backend output.

Foreground wakeword support is available from Settings. When enabled for the
current app session, the app uses Apple Speech while the app is open to listen
for the configured wake phrase (`Hey DJ` by default), then records a short WAV
voice request through the normal `/api/djconnect/v1/voice` flow. The app does not
run an always-on background wakeword listener and does not auto-start wakeword
listening after launch. Wakeword and the local progress timer are paused when
the app leaves the foreground and resume only when the app becomes active
again. Wakeword listening is disabled on iOS Simulator because simulator
speech/audio capture is unstable; test it on a real iPhone or iPad.

Queue requests include `limit:100`. Responses may use `queue.items` plus
`queue.context`, flat `queue` arrays, or flat `items` for compatibility. The
app also accepts top-level `context_uri` and `contextUri` and supports album-art
aliases `album_image_url`, `media_image_url`, `image_url`, and
`entity_picture`. Home Assistant should return real queue items only, without
padding repeated copies of the current track.

Command responses are transport success first and playback-state second.
`success:true` with `playback.has_playback:false` is a valid empty playback
snapshot, not an error; playback fields such as progress, duration, volume,
track metadata, context and artwork URLs may be `null`.

When the app has a reachable local Home Assistant URL, an explicit feature flag,
and a valid Home Assistant WebSocket auth token, it may use the native Home
Assistant `/api/websocket` API as an optional fast path for supported DJConnect
command, Ask DJ message/history, and Track Insight actions. HTTP remains the
canonical transport and all remote/Nabu Casa sessions stay HTTP-only unless a
future client explicitly proves HA WebSocket auth for that URL class. The paired
DJConnect `device_token` never authenticates `/api/websocket`; it is included
only inside DJConnect payloads after HA WebSocket auth succeeds. Any WebSocket
auth, timeout, disconnect, protocol, malformed result, or capability failure
falls back to the existing HTTP request once without clearing pairing or
exposing tokens in logs. Clients must first request `djconnect/capabilities` on
the authenticated Home Assistant WebSocket and only send advertised routes such
as `djconnect/command`, `djconnect/ask_dj/message`,
`djconnect/ask_dj/history`, `djconnect/ask_dj/history/clear`, and
`djconnect/track_insight` and `djconnect/vibecast`. Diagnostics export only
transport state, advertised route names, capability refresh time, and a redacted
last error.

VibeCast on iOS and macOS uses the same authenticated backend contract:
`GET /api/djconnect/v1/vibecast`. The request sends the paired device identity
and canonical `client_type` through the existing bearer-token headers plus
locale, timezone, app version, and supported render capabilities. The response
is backend-neutral structured JSON with `enabled`, `reason`, `revision`,
`ttl_seconds`, `poll_after_seconds`, current-track `context`, and feed `items`.
Items render safe rich-text segment types (`text`, `strong`, `emphasis`,
`emoji`, `magnify`, `accent`, `line_break`) directly; clients advertise
`emoji_safe` when emoji can be shown inline, do not parse HTML or Markdown, and
unknown segment types fall back to plain text. Polling runs only
while the VibeCast surface is visible, respects `poll_after_seconds`, clears old
bubbles when `context.track_id` changes, and treats disabled/error reasons as a
quiet empty state without clearing pairing unless the app-wide stale-pairing
logic applies. When local HA WebSocket fast-path is enabled and Home Assistant
advertises `djconnect/vibecast`, the same response contract may be fetched over
WebSocket; missing capability or transport failure falls back to HTTP once.
While VibeCast is visible, iOS/macOS also keep Track Insight warm client-side:
the app auto-analyzes the current playing track and each next playing track
with `open:false`, deduping repeated playback snapshots until VibeCast closes.
The iOS AirPlay VibeCast video renderer preloads album artwork before encoding
the MP4 frames; if Track Insight has no artwork URL it falls back to the current
Now Playing artwork URL so AirPlay does not bake in the placeholder while the
live VibeCast window loads images asynchronously.

All status and command payloads include `device_id`, `client_type`, and
`firmware`. The `firmware` value remains the protocol compatibility version,
even for app clients.

Pairing is posted to:

```http
POST /api/djconnect/v1/pair
```

The app sends `device_id`, `device_name`, canonical `client_type`, `firmware`,
`app_version`, `platform`, and the 6-digit Home Assistant setup code as
`pair_code`, `pairing_code`, and `pairing_token`. Pairing bootstrap is
local-only: the Apple client posts to the local Home Assistant
`/api/djconnect/v1/pair` endpoint and stores the returned DJConnect bearer token,
`ha_local_url`, optional `ha_remote_url`, remote support flag, API
paths/capabilities, and music-backend summary. Remote URLs are never used for
first pairing. For development, `https://*.ngrok-free.dev` is whitelisted as a
tunnel URL; other remote HTTPS URLs are rejected for first pairing.

The pairing flow is two-phase. A successful pair response stores the returned
token, then the app waits for authenticated status to succeed before showing the
runtime as paired. `client_type_mismatch` during pairing keeps the entered URL
and code intact and tells the user to select the matching Home Assistant setup
flow: iPhone/iPad uses `ios`, macOS uses `macos`, and Apple Watch pairing
through iPhone uses `watchos`.

iOS primarily pairs from the Home Assistant QR/deep-link payload
`djconnect://pair?ha_url=<local-ha-url>&pair_code=<code>&client_type=ios&pair_path=/api/djconnect/v1/pair`.
Manual local URL plus 6-digit code entry remains a fallback.

iOS and macOS no longer host a Home Assistant-callable local Client API and do
not expose any app-hosted Home Assistant callback API or pairable discovery service.
The app does not implement ESP-only reboot or OTA routes.

Users can choose `App opnieuw koppelen` / `Pair App Again` in Settings to clear
the locally stored DJConnect token and reopen the pairing sheet for a fresh
Home Assistant setup code.

After successful local pairing, iOS and macOS choose the local HA URL when it is
reachable, fall back to `ha_remote_url` when local access fails and remote is
supported, and mark the app offline when neither URL works. watchOS remains
iPhone-mediated and does not use a direct Home Assistant remote/local contract.
From the offline state, the Wi-Fi/settings shortcut tries system network
settings and does not intentionally fall back to the DJConnect app settings page.
The status surface reports the active route, music backend availability, and
whether playback controls are available, paused, playing, or waiting for an
active playback snapshot.
The iPhone syncs a compact summary to the Watch for About/status UI:
connection mode (`local`, `remote`, `offline`), backend id/name/availability,
backend revision, target player, capabilities, and safe backend error messages
or codes. Watch playback actions keep the complete backend-owned action
`value`, so Spotify Direct URI actions and Music Assistant object actions are
both forwarded unchanged through iPhone.

## Version Contract

DJConnect clients and the Home Assistant integration must share the same
`major.minor` protocol version. Patch versions may differ.

If Home Assistant returns HTTP `426` with `error: "version_mismatch"`, the app
must keep pairing and token state, show an update-required state, and pause
command/voice retries until the app or integration is updated.

Successful status and command responses may also include `ha_version` or
`ha_major_minor`. App `3.2.x` requires HA integration `3.2.x` and disables
playback, queue, playlist, output, liked, and voice controls when the runtime
contract is outside that range. Settings and pairing reset remain available.

## Diagnostics And Crash Reports

Diagnostics are user-mediated. The app redacts tokens and does not upload logs
automatically. If the previous session appears to have ended uncleanly, the
next launch offers to copy redacted logs or open a prefilled GitHub issue in
`pcvantol/djconnect` for manual submission.

The app also keeps a local redacted rolling diagnostic logfile in Application
Support at `DJConnect/Logs/djconnect.log`. It is loaded back into the Logs
screen on restart, capped at 500 lines and 128 KB, and cleared when the user
clears logs in the app.

Diagnostics export includes redacted route, backend, output, permission,
bundle, locale, Demo Mode, and playback snapshot fields so TestFlight/App Store
review and support can verify readiness without receiving tokens, pairing
codes, Authorization headers, raw secret-bearing bodies, or unredacted private
URLs.

DEBUG logs include user actions, navigation/recovery flows, and Home Assistant
API calls. API log lines include HTTP status codes and must not include bearer
tokens, pairing codes, Authorization headers, or raw secret-bearing bodies.

On iOS, returning from the Home screen or another app schedules a full playback
refresh so Now Playing state catches up with changes made outside DJConnect.
Automatic startup/resume refreshes are throttled to avoid repeated network
bursts, while explicit user refreshes remain immediate. While a track is
playing, the progress bar advances locally every second and only checks Home
Assistant periodically or when the track reaches its expected end.

Artwork loading uses a bounded 24-hour in-memory data cache shared by Now
Playing, queue, playlists, and dominant artwork tint sampling. This avoids
fetching and decoding the same album art repeatedly while scrolling or after
short status refreshes.

## Security

Never log bearer tokens, Home Assistant tokens, Spotify refresh tokens, OAuth
client secrets, WiFi passwords, or temporary TTS/audio URLs. See
[PRIVACY.md](PRIVACY.md) for diagnostic redaction rules.
