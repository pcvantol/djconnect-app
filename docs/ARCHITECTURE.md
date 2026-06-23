# Architecture

DJConnect App contains native Apple clients for the Home Assistant `djconnect`
integration. The apps are not ESP32 emulators; they are first-class app clients
identified by `client_type`.

## Trust Boundary

Home Assistant owns:

- pairing and DJConnect bearer-token lifecycle;
- Spotify OAuth and future playback backend credentials;
- playback commands;
- Assist/STT/TTS;
- native Home Assistant entities.

The Apple app owns:

- native iOS/macOS/watchOS UI;
- the shared DJConnect blue/purple gradient canvas on iOS, iPadOS, and macOS;
- local app state;
- local bonus games with app-local highscores;
- local app-private storage for only the DJConnect bearer token;
- a pinned Client adres after successful pairing, kept stable until explicit
  pairing reset;
- local audio recording for push-to-talk, when implemented;
- optional playback of returned DJ response audio.
- user-facing permission status and preflight requests for Microphone and
  Speech Recognition.
- one-time first-run onboarding that points setup to Home Assistant and notes
  the Spotify Premium requirement.
- local Demo Mode state for App Store review and UI inspection without a live
  backend.

The app must never store Spotify, Sonos, Home Assistant long-lived access
tokens, OpenAI, or playback backend credentials.

## Targets

`DJConnectCore`

The UI-free integration contract layer. It builds authenticated requests,
serializes status/command/voice payloads, decodes playback and voice responses,
classifies backend errors, and abstracts token storage.

`DJConnectUI`

Shared SwiftUI screens for iOS and macOS. This module depends on
`DJConnectCore`, but the HTTP client does not depend on SwiftUI. Platform
permission state lives here because it directly controls voice/wakeword UX and
requires Apple UI frameworks.

`DJConnectIOS`

Native iOS app target. It hosts the shared SwiftUI root view in an iOS app
scene.

`DJConnectMac`

Native macOS app target. It hosts the shared SwiftUI root view in a macOS app
scene and exposes a native settings scene.

`DJConnectWatch`

Native standalone watchOS app target. It depends on `DJConnectCore` directly,
stores its DJConnect bearer token in app-private storage, pairs with Home
Assistant using the same app-generated code flow, posts status and playback
commands, exposes `Ask DJ` push-to-talk, uploads WAV audio to
`/api/djconnect/voice`, and plays returned DJ response audio or speech on the
Watch. Wake phrase work on watchOS is foreground-only by design; the app must
not run an always-on background microphone listener.

## Ask DJ And DJ Memory

`Ask DJ` is the user-facing voice/chat feature name. Apple clients may send
lightweight context hints such as mood, DJ style, and a memory key hint with
status or voice requests. Long-term DJ Memory remains server-side in the Home
Assistant DJConnect integration so Watch, iOS, and macOS can share context. A
client may remember local UI preferences such as the current mood slider value,
but it must not be the source of truth for conversation history, music profile,
or cross-device follow-up context.

Ask DJ is also the only Apple-client DJ request surface. Now Playing focuses on
playback status and controls; it must not carry a separate `DJ verzoek` card.
rbpi had no separate rich DJ request UI, and ESP32 remains a firmware/device
surface without the Apple Ask DJ chat UI.

Ask DJ intent interpretation remains backend-owned. In addition to music
questions and playback controls, the integration should handle liking/saving
the current track (`favorite_current_track`) and output-device information
questions (`output_devices_info`, `current_output_info`), fuzzy personalized
mood playback (`personalized_mood_playback`), broad "play something else"
requests (`change_music_context`), and DJ announcement requests
(`dj_announcement_request`). Personal listening-profile questions such as
"waar luisterde ik de afgelopen maand naar?" are handled as
`personal_music_profile_analysis`; the backend should summarize genres, moods,
energy, artists, contexts, and taste shifts from DJ Memory for the requested
period without changing playback. Personal recommendation questions such as
"wat zou ik leuk vinden om nu te luisteren?" are handled as
`personal_music_recommendations`; the backend should recommend concrete tracks,
albums, artists, or playlists from DJ Memory and Spotify profile data without
changing playback unless the user explicitly asks to play or queue them. Rich
now-playing and artist questions are handled as `track_context_info`, including
release year, genre, DJ commentary, artist origin, trivia, samples, related
artists, concerts, releases, and musical connections such as BPM transition or
shared producer/label. Musical and production-analysis questions are handled as
`track_musical_analysis`; the
backend should distinguish documented facts from likely audible interpretation
unless real audio analysis is available. Apple clients send the user's text or
voice audio and render the returned DJ text, images, links, and audio; they do
not inspect phrases such as "voeg dit nummer toe aan mijn favorieten", "welke
speakers zijn er?", "ik voel me moe en geprikkeld", "wat luister ik de laatste
tijd veel?", "geef me een leuke aankondiging voor het volgende nummer", "waarom
koos je dit nummer?", or "analyseer dit nummer muzikaal" locally.

Ask DJ history is synchronized from Home Assistant and cached locally for
performance. Clients merge returned history messages into the local cache so a
bounded server response window does not make older cached messages disappear.
Backend `clear_revision` is the full-clear signal. Backend
`history_trimmed_before` metadata is the retention signal clients may use to
prune old local cache entries. Assistant-only `message_kind: system` messages,
including ambient music facts and history-retention notices, render in the same
timeline with distinct styling.

Ask DJ UI must never show raw backend, proxy, HTML, or decode error bodies.
Technical details belong in redacted diagnostics logs; visible errors stay short
and localized, such as `Ask DJ niet bereikbaar` or `Home Assistant gaf geen
antwoord`.

## State Handling

Pairing/auth failures are intentionally conservative:

- `backend_unavailable`: keep pairing and token, show playback backend state.
- HTTP `426` / `version_mismatch`, or successful responses with incompatible
  `ha_version`: keep pairing and token, show that the HA integration must be
  updated, and disable runtime playback/voice controls.
- HTTP `401`/`403` on authenticated routes: mark pairing stale, keep token until
  user reset.
- HTTP `401`/`403` during unauthenticated pairing polling: stop polling, keep
  the current app-generated code visible, and ask the user to enter that same
  code in Home Assistant.
- HTTP `404`: show integration/setup recovery, keep token until user reset.

Only explicit user pairing reset should clear locally stored token state.

When no bearer token exists, the UI shows a blocking pairing sheet instead of
enabling playback. Pairing success is acknowledged with a dedicated success
state before the main runtime UI is released. Demo Mode is the only unpaired
path that unlocks runtime screens; it uses local sample data and must not
contact Home Assistant. Demo Mode is session-only and is cleared on app
restart, explicit pairing reset, or when the user stops Demo Mode from
Settings. Stopping Demo Mode and resetting pairing both return the UI to Now
Playing with the blocking pairing sheet on top.

Fresh installs seed the Home Assistant URL field with
`http://homeassistant.local:8123`. Once pairing succeeds, runtime traffic uses
the `ha_local_url` returned by Home Assistant instead of this editable setup
default.

The output selector exposes a local `Geen`/`None` state plus real backend
devices returned by Home Assistant. It does not synthesize local platform
outputs. When the no-output state is selected, playback-start commands are
blocked locally so Spotify does not pick an arbitrary Connect device.

Spotify source and liked/default playlist overrides are Home Assistant
integration internals, not client settings. New Apple app setup, Settings, and
onboarding flows must not ask for `spotify_source`, `liked_proxy_playlist_uri`,
"Spotify source override", or "Standaard playlist override"; playback continues
through generic commands sent to Home Assistant.

## Local Client API

The app hosts a small local HTTP API for Home Assistant -> app traffic while
the app is active. User-facing text calls this endpoint `Client adres`.

The Client adres shown during pairing is pinned after successful pairing and
stored locally so Home Assistant does not lose the callback target when the app
refreshes its listener. It changes only when the user resets pairing or the app
installation state is reset.

Bonjour/mDNS advertising is scoped to discovery. The app publishes
`_djconnect._tcp` while it is unpaired/pairable, then disables that Bonjour
service after successful pairing while keeping the HTTP listener alive for
paired Home Assistant callbacks. This avoids unnecessary repeated publication
and reduces network/battery cost on iOS and macOS.

## Battery And Responsiveness

The app treats Home Assistant as the source of truth but avoids polling when
local state can stay responsive by itself. Explicit user refreshes still run
immediately, while automatic startup/resume refreshes are throttled and backend
collection refreshes are rate-limited. During playback, the progress bar
advances locally once per second and only performs a low-frequency status check
or refreshes when the expected track duration is reached.

Foreground wakeword listening is lifecycle-bound. The app starts it only when
the app is active, paired, not in Demo Mode, and the user enabled
stemactivatie. It stops when the scene becomes inactive or backgrounded and
resumes on the next active scene if the user setting still allows it.

Album artwork uses a shared bounded 24-hour data cache across Now Playing,
queue rows, playlist rows, and dominant-color tint sampling. This avoids
duplicate downloads and repeated decode work during list scrolling and status
refreshes.

## Logging

Debug logging is designed for support without leaking secrets. The app logs
user actions and navigation/recovery flows at DEBUG level, including refresh,
transport controls, queue/playlist starts, output changes, Demo Mode entry/
exit, pairing reset, wakeword prompt decisions, and voice/PTT actions.

Home Assistant API calls and local Client API calls log method/path plus HTTP
status code. Logs must not include bearer tokens, pairing codes, Authorization
headers, Spotify/Home Assistant credentials, passwords, or raw request/response
bodies that may contain secrets.

Runtime diagnostics are kept in memory for the Logs screen and mirrored to a
redacted rolling logfile in Application Support:
`DJConnect/Logs/djconnect.log`. The file is capped at 500 lines and 128 KB,
loaded on app restart, and removed when the user clears logs. The app never
uploads this file automatically.

## Local Games

The Games menu is intentionally outside the Home Assistant protocol. Paddle
Rally, Meteor Run, Sky Dash, and Maze Chase run fully inside SwiftUI, store
highscores in app-local preferences, and do not use `DJConnectCore`, bearer
tokens, Client API routes, or HA command/status endpoints. When focused, the
game surface consumes arrow keys and space so keyboard input controls the game
instead of app navigation. This keeps the Apple app aligned with the ESP bonus
games while preserving the integration trust boundary.

## Project Generation

`project.yml` is the XcodeGen source of truth. Regenerate the Xcode project
with:

```sh
xcodegen generate
```

The generated `DJConnectApp.xcodeproj` is committed so the repo opens directly
in Xcode.
