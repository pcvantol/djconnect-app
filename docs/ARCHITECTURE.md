# Architecture

DJConnect App contains native Apple clients for the Home Assistant `djconnect`
integration. The apps are not ESP32 emulators; they are first-class app clients
identified by `client_type`.

## Trust Boundary

Home Assistant owns:

- pairing and DJConnect bearer-token lifecycle;
- Spotify Direct, Music Assistant, and future playback backend credentials;
- playback commands;
- Assist/STT/TTS;
- native Home Assistant entities.

The Apple app owns:

- native iOS/macOS/watchOS UI;
- the shared DJConnect blue/purple gradient canvas on iOS, iPadOS, and macOS;
- local app state;
- the device-local Glass effects preference: shared UI policy and opaque material
  fallbacks, respecting OS Reduce Transparency; never a backend Profile field;
- local bonus games with app-local highscores;
- local app-private storage for only the DJConnect bearer token;
- iOS/macOS Home Assistant URL state after local pairing, including local URL,
  optional remote URL, and local/remote/offline diagnostics;
- local audio recording for push-to-talk, when implemented;
- optional playback of returned DJ response audio.
- user-facing permission status and preflight requests for Microphone and
  Speech Recognition.
- one-time first-run onboarding that points setup to Home Assistant and notes
  the Home Assistant-owned music backend requirement.
- explicit local Demo Mode for App Store review without a live backend: curated
  current/native Session, readonly earlier Sessions and scripted text/voice examples
  use the same views/models. Examples remain in memory, make no server requests,
  confer no Profile authority and are excluded from ordinary chat/widget persistence.

The Apple app does not own Profile resolution. Application session state is
device/client runtime state. Profile state is backend-owned and may be selected
explicitly only through the canonical Profile context fields supported by the
Home Assistant Profile Platform. The local architecture is:

```text
Application Session
  -> Profile context signal
  -> Device identity
  -> Home Assistant backend
  -> selected music backend
```

Local cache is a rendering optimization. It must not become Profile ownership:
Ask DJ history, Music DNA, Discover recommendations, Track Insight context,
mood persistence, response style, household membership, music account state and
backend routing remain Home Assistant-owned. Private Session requests use the
resolved backend Profile for routing but suppress backend persistence according
to Home Assistant policy; clients should avoid adding durable local personal
cache for those request results.

The app must never store Spotify, Sonos, Home Assistant long-lived access
tokens, OpenAI, or playback backend credentials.

Apple STT is a separate, opt-in installation-local input preference. On iOS,
iPadOS and macOS, Ask DJ and the Session composer share the same microphone
capture route. With this preference enabled, a temporary recording is recognized
only when Apple reports on-device support for the app language; the recognition
request explicitly requires on-device processing. Only the final text enters the
existing Ask DJ draft/send path. It adds no backend contract or Profile setting.
Recognition failure never falls back to HA audio. Capture cancellation, background,
owner/session/selected-entry changes, changed language or a modified draft fence
late results. Temporary recordings are removed on completion or cancellation.
The existing wake recognizer also requires local processing while this option is
enabled. Local STT does not enable TTS, autoplay or any HA speaker output.

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

Apple Hybrid transport is automatic for an existing paired identity with a stored
installation ID and configured endpoints. `DJConnectHybridTransport` owns one
foreground route/context probe shared by clients. Remote routes require HTTPS
with normal certificate and hostname validation before credential release.
A local HTTP candidate must exactly match the already configured paired local
origin. Private-address syntax alone does not authorize plaintext transport.

The authenticated request context must match the paired installation and the
complete Core policy-version-1 contract. HTTP is admitted only for Core-qualified
direct ingress with `mode: qualified_direct_http` and
`requires_authenticated_tls: false`. The paired-owner action socket maps that
route to WS and independently validates the `auth_ok` policy before executing;
HTTPS maps to WSS. The global TLS-required capability is not a local exception.
Missing qualification, conflicting socket policy, redirects and remote HTTP
cannot authorize a downgrade. The old opt-in setting and automatic
`/websocket/session` issuer dependency remain removed; explicit legacy APIs are
compatibility-only.

Core owns ingress qualification, including actual peer/interface evidence and
the operator record. Apple does not infer that evidence from configured URLs,
forwarded headers or a Docker NAT gateway. HTTP426 with
`transport_security_required`, or its socket equivalent, withdraws only the
route and temporarily excludes it for sixty seconds. Pairing, Profile and UI
state remain intact. Before possible transmission there is no fallback execute;
after possible transmission recovery uses only the original operation identity
and status through an already trusted TLS route, never an execute replay.
About reports the actual active HTTP/WS LAN or HTTPS/WSS TLS route and no active
origin while offline. See
[installed Core evidence](feedback/APPLE_CORE_INSTALLED_TRANSPORT_20261016.json)
and [LAN qualification boundary](feedback/APPLE_LAN_TOPOLOGY_20261016.md).

`DJConnectPairedActionConnection` owns a single reader, connection-ID/request-ID
demultiplexing and serialized writes. It bounds outstanding requests, frames and
IDs, authenticates within five seconds, pings every fifteen seconds and closes
before the five-minute lease expires. Socket closure updates UI diagnostics.
Backgrounding closes connections and cancels foreground work.

Supported mutations receive an original UUIDv7 and server operation epoch. After
possible transmission, recovery queries status for that same identity instead
of executing again. Confirmed receipts remain confirmed when the result body is
unavailable. Only compact, bounded receipt metadata is retained in RAM; prompts,
audio, personal responses and history are not journaled. Legacy effectful POSTs
cannot be replayed after a network failure. Pure reads, history paging, voice,
uploads, files, Discover and Music DNA retain their HTTP contracts.

Active DJ Session delivery remains a separate paired-owner Broadcast connection.
Its foreground HTTP recovery consumes opaque server recovery cursors, validates
session identity and applies existing event sequence/watermark guards. A required
snapshot exposes a coverage-gap notice instead of pretending missed events were
replayed. Backgrounding, termination and authority withdrawal stop recovery.
Route changes preserve the existing UI draft, selection, subject and scroll
state; they do not start a session or transfer playback.

The connection popover uses the combined health status. Every status other than
green local-connected offers Details, opening About through the root navigation.
About separates overall health, route, transport and the authenticated active
origin. An inactive/unconfirmed origin is labelled as such; configured addresses
are never presented as proof of an active authenticated route. Remote HTTPS is
a working route even though its colour and icon differ from local connectivity.
Native network-transition and installed hardware acceptance remain separate
from source tests; see the Hybrid adoption report.

`DJConnectWatch`

Native companion-only watchOS app target. It depends on `DJConnectCore`
directly for shared models and serialization, but it does not own Home
Assistant transport. The Watch keeps its own `client_type:"watchos"` identity
and compact UI cache; the paired iPhone owns HA pairing, token storage,
local/remote/offline selection, APNs registration, status refresh, Ask DJ
history sync, playback action forwarding, clear history, idle suggestions, and
voice upload. The Watch does not store `ha_remote_url`, does not host a local
Web API, and does not advertise pairable discovery. Wake phrase work on watchOS is
foreground-only by design; the app must not run an always-on background
microphone listener.

## Ask DJ And Music DNA

`Ask DJ` is the user-facing voice/chat feature name. Apple clients may send
lightweight context hints such as mood, DJ style, and a Music DNA key hint with
status or voice requests. Long-term Music DNA remains server-side in the Home
Assistant DJConnect integration so Watch, iOS, and macOS can share context. A
client may remember transient control presentation, but Persona, voice, gender,
Mood, presence and announcement output are Profile-bound backend settings under
settings3. Local preview/control state never overrides confirmed defaults or
Session revisions. Conversation history, music profile and cross-device context
also remain backend-owned.

Music DNA export/import follows the same boundary. Apple clients may request a
server-built export envelope over authenticated HTTP and save it through native
Files/Finder UI, but the export body is exactly the Home Assistant response.
The app does not synthesize Music DNA backup JSON from cached profile state and
does not add OAuth credentials, DJConnect bearer tokens, raw prompts, raw audio,
diagnostics, or local caches. Import is allowed only while paired and connected,
with stale/auth failures routed through the regular pairing recovery path.
Export/import never use the Home Assistant WebSocket fast path; only Music DNA
profile, settings, and clear can use advertised fast-path routes.

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
energy, artists, contexts, and taste shifts from Music DNA for the requested
period without changing playback. Personal recommendation questions such as
"wat zou ik leuk vinden om nu te luisteren?" are handled as
`personal_music_recommendations`; the backend should recommend concrete tracks,
albums, artists, or playlists from Music DNA and Spotify profile data without
changing playback unless the user explicitly asks to play or queue them. The
selected backend can be Spotify Direct, Music Assistant, or a future HA-side
backend; Apple clients render backend summaries and action payloads without
requiring Spotify URIs. Rich
now-playing and artist questions are handled as `track_context_info`, including
release year, genre, DJ commentary, artist origin, trivia, samples, related
artists, concerts, releases, and musical connections such as energy flow or
shared producer/label. Technical and production-analysis questions are handled
as `track_insight`; the backend should distinguish measured/provider
metadata from inferred musical commentary and must keep the intent read-only
unless real audio analysis is available. Apple clients send the user's text or
voice audio and render the returned DJ text, images, links, and audio; they do
not inspect phrases such as "voeg dit nummer toe aan mijn favorieten", "welke
speakers zijn er?", "ik voel me moe en geprikkeld", "wat luister ik de laatste
tijd veel?", "geef me een leuke aankondiging voor het volgende nummer", "waarom
koos je dit nummer?", or "analyseer dit nummer muzikaal" locally.
Structured output `playback_actions` are rendered as vertical speaker rows with
the speaker name on the left and the `Actief`/`Activeer` button on the right;
selecting a row sends the backend-owned output switch command.

Ask DJ request payloads may include optional backend-owned `metadata` for
context triggers. The planned morning startup flow sends
`metadata.trigger == "morning_startup"` with `Goedemorgen` or `Good morning`
when the app opens in the morning without active playback. Home Assistant
should answer through the normal Ask DJ response/follow-up path; Apple clients
must not start music automatically for this trigger.

Backend follow-up and confirmation prompts are rendered as Ask DJ
`playback_actions`. For general clarification, Home Assistant can return
actions such as `kind: "confirmation"`, `action_style: "confirmation"`,
`response_value: "yes"` or `"no"`, and
`command: "ask_dj_followup_response"`. Apple clients show the buttons and send
the selected action back; pending follow-up state and final intent execution
remain server-side.

Ask DJ history is synchronized from Home Assistant and cached locally for
performance. Clients merge returned history messages into the local cache so a
bounded server response window does not make older cached messages disappear.
Backend `clear_revision` is the full-clear signal. Backend
`history_trimmed_before` metadata is the retention signal clients may use to
prune old local cache entries. Assistant-only `message_kind: system` messages,
including ambient music facts and history-retention notices, render in the same
timeline with distinct styling. When the Ask DJ screen opens, clients scroll to
the newest timeline message by default, including after the first async history
load.

Profile-aware Ask DJ, Music DNA, Discover, Track Insight, command, and voice
requests use the canonical Profile Adoption Contract from
`pcvantol/djconnect/docs/implementation/epic3b/01-profile-adoption-contract.md`.
Clients may send only known context fields: `profile_id`, `session_id`,
`private_session`, `request_source`, `device_id`, and `client_type`. They must
not send OAuth tokens, provider refresh tokens, Home Assistant tokens, APNs
tokens, raw prompts, raw audio, Ask DJ history, Music DNA contents, or provider
credentials as Profile context.

The clear-history command is a backend call to
`POST /api/djconnect/v1/ask_dj/history/clear`. Clients clear local cached history
only when the backend returns an advanced `clear_revision`; this keeps
cross-device clears authoritative and avoids treating a bounded history window
as a deletion signal.

Individual contribution deletion uses the backend-owned
`SESSION_CONTENT_DELETION_V1` contract: an exact server target is prepared before
explicit confirmation of its full exchange/Moment/dependency scope. Context menus
and horizontal row reveal use the same action. Standalone Profile messages carry
an explicit empty Session ID; clients never infer the current Session or exchange
membership from text/adjacency. These closed-allowlist routes use only flat
`device_id`/`client_type` with the existing Bearer credential, not the generic rich
identity wrapper. Capabilities and exact version1 gate every operation.

Before a confirmed POST, an installation-local bounded journal synchronizes the
original operation/body, prepared identifiers and hashed owner/device/credential
bindings. It contains no prompt, response body or bearer credential. Unknown or
expired outcomes prevent new operation IDs, including after model reconstruction.
An explicit status action uses GET with the original operation/confirmation only;
it never replays a POST or renews its lifetime. A bound completed receipt withdraws
affected grants/cache epochs; fresh admitted reads precede clearing the journal.
Unrelated pending asks or voice capture prevent this cache transition, and the
composer is gated during the transition. Whole-session deletion remains a separate
archive contract with its existing journal; it cannot borrow a content token.

Ask DJ text and command payloads carry explicit app identity fields:
`device_id`, `device_name`, `client_id`, and `client_type`. `client_id`
currently mirrors `device_id`. When users tap backend-provided
`playback_actions`, clients prefer sending the returned action object back,
including nested object `value` payloads, so follow-up state and output
selection remain backend-owned.

Ask DJ UI must never show raw backend, proxy, HTML, or decode error bodies.
Technical details belong in redacted diagnostics logs; visible errors stay short
and localized, such as `Ask DJ niet bereikbaar` or `Home Assistant gaf geen
antwoord`.

## State Handling

Pairing/auth failures are intentionally conservative:

- `backend_unavailable`: keep pairing and token, show temporary playback
  backend recovery state, throttle repeated notices, and retry automatically.
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

The output selector exposes real backend devices only. Synthetic local/None/no
selected-device rows are filtered; an absent selection is an unavailable state,
not a playable output. Unknown/non-controllable volume displays a dash and does
not expose a writable slider. A Bluetooth glyph requires a reliable route signal;
a device name alone never establishes Bluetooth capability.

On iOS, one model-owned, in-memory audio-route snapshot observes
`AVAudioSession.routeChangeNotification` and refreshes on foreground entry.
For the current, connected, non-cached phone/tablet playback output only, its
display name can use the active Bluetooth port's `portName`. Known conflicting
local device aliases, blank/multiple names and mixed routes suppress that alias.
The output inventory, backend name and command device ID remain authoritative
and unchanged. Now Playing, the Session header and the output selector share
this presentation. Reading the route neither activates an audio session nor
changes routing; it does not persist a Profile preference or imply lossless audio.

Demo artwork is local presentation: Now Playing, the Session music header and
Track Insight use the existing vinyl placeholder rather than remote cover art.
`AlbumArtworkPlaceholder.swift` is compiled into iOS/macOS UI and the Watch app
from one source file. The Watch uses it for the demo player thumbnail, artwork
preview and Track Insight. A width-only layout proposal still reserves a square;
rotation follows playback and stops for inactive scenes or Reduce Motion. Real
Session artwork continues to require its existing backend media grant.

Spotify source and liked/default playlist overrides are Home Assistant
integration internals, not client settings. New Apple app setup, Settings, and
onboarding flows must not ask for `spotify_source`, `liked_proxy_playlist_uri`,
"Spotify source override", or "Standaard playlist override"; playback continues
through generic commands sent to Home Assistant.

## Home Assistant Transport

iOS and macOS call Home Assistant directly after local pairing. Pairing uses the
local `/api/djconnect/v1/pair` endpoint only. Runtime traffic uses the stored
`ha_local_url` first, falls back to the optional `ha_remote_url` when remote is
supported and local access fails, and reports `offline` when neither route
works.

watchOS does not own Home Assistant transport. The Watch sends typed
WatchConnectivity requests to the paired iPhone; the iPhone performs HA pairing,
status, commands, Ask DJ history, clear history, idle suggestions, voice upload,
and push registration on behalf of the Watch while preserving
`client_type:"watchos"` metadata.

No Apple target hosts a Home Assistant-callable inbound API, shows a callback address, or advertises a pairable discovery service.

## Battery And Responsiveness

The app treats Home Assistant as the source of truth but avoids polling when
local state can stay responsive by itself. Explicit user refreshes still run
immediately, while automatic startup/resume refreshes are throttled and backend
collection refreshes are rate-limited. Playback backend recovery uses lightweight
throttled refreshes so temporary `backend_unavailable` states can clear without
stacking full collection refreshes. During playback, the progress bar advances
locally once per second and only performs a low-frequency status check or
refreshes when the expected track duration is reached.

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

Home Assistant API calls log method/path plus HTTP status code. Logs must not
include bearer tokens, pairing codes, Authorization headers, Spotify/Home
Assistant credentials, passwords, or raw request/response bodies that may
contain secrets.

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

## Session passive surface consolidation (2026-10-15, consumer foundation)

The selected user request replaces the independent widget experiences with a
single active-Session system. All passive consumers now share the neutral
DJConnectSessionSurfaceSnapshot runtime contract; legacy configured identifiers
are migration aliases. Activity lifecycle follows confirmed Session lifecycle,
not playback. Standalone feature deep links remain unchanged. Watch's separate
container does not receive implicit iPhone state or private content.

The consumer uses the frozen Core passive projection2cb87cb7 wire fields and
independent RAM grants. The owner's later 2026-10-17 instruction removes the
extra per-Session pop-out: a fresh confirmed Session plus configured OS widgets
or enabled iOS Live Activities now triggers foreground preparation automatically.
A new process obtains a new grant rather than trusting stored pixels. Core owns
the corresponding consent-policy/SYNC acceptance; the concrete handoff is linked
in feedback/APPLE_PASSIVE_AUTOMATIC_SURFACES_20261017.md. No new backend wire fields,
private owner export or Watch replication are inferred.

The passive owner fence follows the independently confirmed settings3 binding,
not conversation history's suspension epoch. Backgrounding preserves already
granted cache only to its original deadlines. Automatic preparation uses the
existing foreground coordinator, throttles OS configuration queries to30seconds,
and never blindly replays uncertain authorization. OS removal revokes the surface
and fences late pixels. Activity bookkeeping separates confirmed dismissal from
app retirement and build updates; confirmed user dismissal remains respected.
Qualification processes cannot publish real AppGroup/ActivityKit content.

The physical iPad read before the fix found3configured widgets, OS authorization
and an active server Session, but no caches or Activity. Subsequent ordinary
40268/40269 preparation populated both independent stores;40269's actual read
confirmed fresh contribution and music. This is not an OS-pixel or artwork PASS.
The current Core contract advertises background_delivery=false. No polling loop,
source-TTL extension or ordinary APNs-to-ActivityKit assumption is introduced;
sustained background/locked delivery and original-source pixels remain producer
and joint acceptance work. See feedback/APPLE_INTEGRAL_EXECUTION_20261017.md.



The subsequent explicit user request adds Session-mood styling to this consumer
foundation. The app's existing confirmed Core mood selects a closed renderer
palette token with the same transient UI lifetime. A shared palette definition
feeds Session UI, widgets and Activity/Island accents; no local Mood inference,
new backend request/wire field, free text, personal identifiers or rich content
rights are introduced. Missing/unknown/expired Session style uses brand colors.
A changed palette requests reload promptly, while freshness renewals use a
separate bounded reload clock. ActivityKit/background and rich-content producer
qualification remain open; local style does not qualify either capability.

## Shared DJ settings and private Session media (2026-10-17)

Settings3 is the only negotiated durable owner of the six shared DJ choices.
Persona, Mood and presence have separate quick controls. The DJ voice popover is
under Session ellipsis only; it is not a bubble-specific setting or Settings
page. Confirmed text_only hides voice/gender/autoplay and all bubble audio
controls, retains the selected voice backend-side and produces no speech. The
local autoplay toggle is client runtime, never a shared Profile default.

Speech3 prepares/replays the exact accepted owner contribution with settings,
source, revision, retention and lifecycle fences. HA-configured synthesis uses
the user's actual provider. Device-local Apple voice preferences and the bounded
static sample use one native speech renderer shared by iOS/iPadOS/macOS/watchOS.
They do not write Profile settings or enable autoplay. Unknown/text_only policy
blocks the sample. Enabling the override suppresses local HA synthesis; explicit
HA speaker delivery remains independent. Speech3 local_on_device admission now
feeds the shared native renderer for manual and automatic contribution playback.
Only admitted segments may be spoken; source/settings/revision/expiry fences remain
mandatory. Native playback never fetches HA audio or falls back to visible text.
The stored HA voice is hidden while Apple TTS is enabled and shown unchanged when
it is disabled. Returning from Apple STT requalifies HA input with a fresh status
read; capture still requires fresh admission. A player-start
log is not acoustic completion.

Private artwork preparation is viewport-driven, bounded and separate from pure
history reads. Image GET and history GET share complete device/client query
identity plus bearer headers. No-store, no redirects, byte/decoded geometry caps,
exact subject attribution, original expiry and owner withdrawal remain mandatory.
An unavailable/insufficient_identity projection cannot borrow NowPlaying art.
Actual acceptance and outstanding work are recorded in
feedback/APPLE_OPEN_WORK_20261017.md, independently of these architecture rules.


The playback output list and Now Playing label are reconciled from the same
newly observed current playback device. Refreshing outputs reads inventory and
current playback without issuing a transfer; an older inventory response cannot
overwrite a newer playback observation. Exact stable IDs retain precedence over
ambiguous display names. An unsuccessful transfer is an action-local outcome,
not sufficient evidence to withdraw otherwise confirmed music-backend health.


## Shared settings and Watch foreground delivery (2026-10-17)

ProfileDJSettingsModel lives in DJConnectCore and is reused by iOS/macOS and
Watch presentation. Authenticated settings3 supplies its own Profile binding:
startup must not wait for Ask DJ/history to load. The local task fence follows
the paired device/installation and confirmed Profile changes, preserves uncertain
operations through ordinary history suspension and URL updates, and rejects
Profile ABA or an incompatible server binding. Explicit authority withdrawal
clears visible values without replaying an unresolved PATCH.

The Watch reads existing owner Session/settings routes with its own paired Watch
identity via the iPhone proxy. Only currently admitted complete contributions and
flow cards cross this interactive bridge; no passive iPhone grant, bearer,
artwork cache, hidden history or future plan labels are replicated. Source and
display deadlines remain intact. Interactive replies never enter application
context or transferUserInfo; eight requests and a20-second timeout/cancellation
bound outstanding work. No native Watch runtime acceptance follows from the
signed embedded build. Ordinary Watch personal mood hints have been retired;
Demo state and genuinely local client controls remain device-local.


## Watch Session native replay (2026-10-18, candidate40318)

Watch main presentation puts current playback before the latest native-admitted
Moment, then an explicitly expandable admitted Session flow (at most eight other
cards). Original complete text, timestamps, attribution and display/source
expiry remain authoritative. The four presence choices share the Core client
presentation list; historical talkative still decodes without being selectable.

The frozen Core local settings3 handoff bc6e080e authorizes manual Apple-native
replay. Compact source revision/locale/attribution/expiry metadata accompanies
only visible Watch cards, never executable speech segments, audio or an iPhone
bearer. It is an internal interactive companion DTO, not a new backend API.
The iPhone re-reads settings and active Session using the Watch's own identity,
compares the original exact card, prepares processor local_on_device with only
reference/intent/target and Watch identity, and re-reads both owners before reply.
No operation replay is allowed. Old companions without metadata still display
cards but cannot grant speech. No HA voice availability or HA audio asset is
needed; native output cannot dispatch a speaker operation.

The Watch's device-local opt-in/installed voice/gender/rate/pitch controls remain
separate from shared Profile settings. A fresh renderer_pending grant must have
exact text/reference/presentation/Persona/locale/attribution/settings revisions,
no effective HA voice or audio asset, and a nonrenewable original deadline.
One playback coordinator owns pending work and output. Stop/replacement,
foreground loss, owner/setting/source withdrawal or expiry, navigation away,
voice inventory/audio interruption/route change terminate output. text_only and
unknown/invalid policy deny speech. There is no visible-text fallback, background
speech queue or refresh/reconnect autoplay; automatic publication is not inferred
from manual prepare or latest-card appearance.

The broader iPhone/macOS contribution routing is still separate; this increment
connects actual native Moment replay on Watch only. See
[Watch evidence](feedback/APPLE_WATCH_SESSION_TTS_40318_20261018.md). Build/test
qualification is not physical Watch UI, audible or Bluetooth acceptance.


## Passive diagnostics and compact Session toolbar (2026-10-18)

PassiveSessionSurfaceModel emits lifecycle-only diagnostics through the existing
app logger: surface, fixed failure class, configuration booleans and field counts.
It emits no source text, owner/reference IDs, grant IDs, raw server messages or
credentials. Logging does not authorize/retry grants, extend deadlines or create
another content store. Diagnostic privacy and single-attempt behavior are tested.

Compact Session navigation uses a bounded horizontal row in one leading toolbar
item with44point targets. Native UI qualification found that separate leading
items let iOS hide the independent connection/refresh group. The bounded row
preserves More first and source popover anchors; iPad retains direct expanded
controls. Native simulator screenshots/tests qualify arrangement and search/menu
interaction only, not physical performance or backend availability.


## Owner-bound Apple consumer consolidation (2026-10-23)

The current-recording Track Insight selector captures an exact playback URI,
original observation lifetime and Session/Profile settings generation before
capability negotiation. Both pending responses and accepted proof are withdrawn
on owner, settings, foreground or recording-context change. The proof remains
ephemeral. Captured reply artwork is independently capability-gated and joins
only an original retained assistant entry and its recorded edition. It never
borrows current playback artwork. See the exact producer pins and causal tests
in [the consumer evidence](feedback/APPLE_CURRENT_INSIGHT_REPLY_ARTWORK_20261022.md).

DJ Bulletin renders an admitted owner Flow Moment in the existing card and
speech pipeline. RSS selection, durable intelligence and publication remain
Core-owned. The preparatory producer fixture and component UI qualification do
not establish operative publication or audible acceptance. Contextual Ask DJ
suggestions and Help use the pinned Core catalogue; unqualified entries do not
become executable client recommendations.

VibeCast same-key recovery preserves the original enrollment challenge, key and
deadline. Replacement/rollover composition is still preparation: the bounded
child journal CAS store and retained-identity file exclusion have no product
factory, allocator, migration or activation path. Their source review does not
open SDK or service admission. See [composition](VIBECAST_HANDLE_JOURNAL_COMPOSITION.md)
and [child storage](VIBECAST_CHILD_JOURNAL_STORE.md). Shipping and ordinary QA
remain closed without an exact finite native policy and external admission.
