# DJConnect App Chat Bootstrap Prompt

Use this prompt to initialize a fresh Codex chat for this repository:

```text
Werk in repo:
`/Users/pcvantol/Documents/GitHub/djconnect-app`

Lees eerst:
- `HANDOFF.md` indien aanwezig
- `docs/HANDOFF.md`
- `README.md`
- `CHANGELOG.md`
- `docs/RELEASE.md`
- `CONTRIBUTING.md`

Context:
- Dit is de native DJConnect app repo voor iOS/iPadOS/macOS/watchOS.
- DJConnect wordt ontwikkeld en onderhouden met AI-assisted/agentic engineering workflows, inclusief Codex; accepted changes blijven maintainer-reviewed en prompts/logs/issues mogen geen secrets of private data bevatten.
- Project is MIT-licensed; zie `LICENSE`.
- Apple app clients tonen geen `Client adres` meer; iOS/macOS pairen lokaal
  met Home Assistant en watchOS loopt via de iPhone companion.
- Clients mogen geen `spotify_source` / "Spotify source override" of `liked_proxy_playlist_uri` / "Standaard playlist override" meer tonen, documenteren of verwachten.
- Backend playback loopt via de Home Assistant DJConnect integration; clients sturen generieke playback commands.
- Apple clients bewaren alleen het door Home Assistant uitgegeven DJConnect device-token in app-private storage. Gebruik geen Keychain en toon geen Keychain-permissie of fallback-popup. `App opnieuw koppelen` wist lokale pairing/token-state, roteert de lokale clientidentiteit/koppelcode waar nodig en opent opnieuw de pairingflow.
- Pairing gebruikt Home Assistant `/api/djconnect/v1/pair` met canonical `client_type`: macOS=`macos`, iPhone/iPad=`ios`, Apple Watch via iPhone proxy=`watchos`. Eerste pairing is lokaal; `https://*.ngrok-free.dev` is alleen als dev-tunnel whitelisted. `client_type_mismatch` houdt URL/code intact en toont een platformspecifieke melding om de juiste HA setup-flow te kiezen.
- Gebruik `/Users/pcvantol/Documents/GitHub/djconnect/SYNC_PROMPTS.md` als enige centrale bron voor cross-repo contracten. Maak geen lokale kopie in deze repo en herintroduceer geen oude losse syncprompt-bestanden. Repo-scheiding: Home Assistant integration=`pcvantol/djconnect`, centrale API=`pcvantol/djconnect-api`, Apple app=`pcvantol/djconnect-app`, Windows=`pcvantol/djconnect-windows`, ESP firmware=`pcvantol/djconnect-esp32`, website/docs=`pcvantol/djconnect-website`, Raspberry Pi=`pcvantol/djconnect-pi`.
- Houd cross-repo contracten actueel met `pcvantol/djconnect/SYNC_PROMPTS.md` en `pcvantol/djconnect/PRODUCT_ROADMAP.md` indien protocol/roadmap geraakt wordt. Apple clients gebruiken Ask DJ als rijke chat/PTT-functie; er is geen losse Now Playing `DJ verzoek` ingang meer. rbpi had die losse ingang al niet; ESP32 krijgt geen Ask DJ rich UI en blijft buiten Apple UI-sync.
- Ask DJ is cross-device: iOS, macOS en watchOS synchroniseren history via Home Assistant en cachen lokaal voor performance. Clients mergen serverberichten in de lokale cache en vervangen de lokale lijst niet door een bounded response-window. `clear_revision` blijft de full-clear authority.
- Bij een nieuw ontvangen Ask DJ antwoord mag een latere history/status sync met hogere `clear_revision` de verse lokale vraag+antwoord exchange niet direct wissen; preserveer berichten met dezelfde `client_message_id` tot HA ze zelf in history teruggeeft.
- Ask DJ history ondersteunt assistant-only systeemmeldingen met `message_kind: "system"`, onder andere `origin: "spotify_playback_context"` voor DJ-feitjes en `origin: "history_retention"` voor limietmeldingen. Deze berichten hebben geen voorafgaande user bubble nodig en zijn niet retrybaar.
- History retention gebruikt backendmetadata zoals `history_limit`, `history_trimmed_before` en `history_trimmed_count`; clients mogen lokale cache ouder dan `history_trimmed_before` opschonen zonder displaytekst te parsen.
- Ask DJ tekstchat stuurt standaard `audio_response: "auto"`. Ontbrekende `audio_url` is normaal; replay/audio UI verschijnt alleen als `assistant_message.audio_url` of top-level `audio_url` aanwezig is.
- Ask DJ mag informatieve vragen, contextuele vervolgreacties, playback-intents, persoonlijke muziekanalyse, aanbevelingen, Play Now-acties, afbeeldingen, links, bronnen en DJ-audio bevatten. Intentinterpretatie blijft backend-owned; clients hardcoden geen intentfamilies behalve UI-weergave van teruggegeven media/actions.
- Ask DJ request payloads mogen optionele `metadata` bevatten voor backend-owned context triggers. De geplande ochtend-start gebruikt `metadata.trigger == "morning_startup"` met tekst `Goedemorgen`/`Good morning` als de app 's ochtends start zonder actieve playback; Home Assistant hoort daarop een normale Ask DJ response/follow-up te maken en niet client-side automatisch muziek te starten.
- Ask DJ tekst- en command-payloads sturen expliciet `device_id`, `device_name`, `client_id` en `client_type`; `client_id` is nu gelijk aan `device_id` voor backendcompatibiliteit.
- Backend follow-up/confirmatievragen worden als Ask DJ `playback_actions` gerenderd. Voor algemene ja/nee verduidelijking gebruikt de backend acties met bijvoorbeeld `kind: "confirmation"`, `action_style: "confirmation"`, `response_value: "yes"|"no"` en `command: "ask_dj_followup_response"`. Clients tonen dan klikbare Ja/Nee knoppen; de pending follow-up state en uiteindelijke intentuitvoering blijven server-side.
- Clients sturen bij action-taps waar mogelijk het volledige door de backend teruggegeven action-object terug, inclusief object-valued `value`; output-actions worden dus niet meer gereduceerd tot alleen een device-id tenzij legacy fallback nodig is.
- Ask DJ clear-history gebruikt `POST /api/djconnect/v1/ask_dj/history/clear`; de backend moet `clear_revision` verhogen en blijven teruggeven, want dat is de authoritative full-clear marker voor lokale caches.
- Raw backend/proxy/decode/HTML-fouten mogen nooit in de Ask DJ chat UI verschijnen. Toon korte gelokaliseerde meldingen zoals `Ask DJ niet bereikbaar` of `Home Assistant gaf geen antwoord`; technische details blijven in diagnostics/logs.
- Track Insight requests sturen `client_type` mee; `invalid_client_type` en `client_type_mismatch` worden gelokaliseerd in UI/logs zonder pairing state te wissen.
- Music DNA gebruikt HA als source of truth, maar na opt-in/opt-out mag de client kort de net gekozen enabled-state vasthouden zodat een stale profile-refresh de toggle niet terugzet. Music DNA gebruikt overal het outline `heart`; filled hearts zijn alleen voor favoriet/save-track.
- Secrets/tokens/wachtwoorden/private URLs mogen nooit in commits, logs, screenshots, diagnostics of test fixtures.

Huidige status om te controleren:
- De actuele Apple app release-prep is `3.2.28`; de gedeelde protocol/releaselijn
  is `3.2.x`, laatst centraal uitgelijnd na Home Assistant integration
  `v3.2.28`. Clients op `3.2.x` zijn compatibel met Home Assistant integration
  `>=3.2.0` en `<3.3.0`.
- iOS/macOS pairen lokaal via `/api/djconnect/v1/pair`, bewaren `ha_local_url`
  plus optioneel `ha_remote_url`, kiezen runtime local -> remote -> offline, en
  hosten geen client `/api/device/*` API of `_djconnect._tcp` service.
- Ask DJ toont in het lege scherm een voorbeeldvraag voor technische
  trackanalyse. Backend/providerdata voor `technical_track_analysis` blijft
  read-only: geen playback starten, pauzeren, skippen, queuen, saven of output
  wijzigen.
- watchOS is volledig companion-only. De Watch host geen lokale Web API,
  adverteert geen mDNS/Bonjour, bewaart geen `ha_remote_url`, en kiest geen
  directe HA local/remote transport. De gekoppelde iPhone is eigenaar van HA
  pairing, Watch-tokenopslag, APNs registratie, runtime transport, status,
  Ask DJ history/clear/idle suggestion, playback actions, follow-up yes/no en
  voice/PTT upload. De iPhone behoudt `client_type:"watchos"` metadata richting
  HA.
- Apple clients renderen de 3.2 music-backend summary (`music_backend`,
  `music_backend_name`, availability, revision, capabilities, target player,
  error) zonder Spotify-only aannames. Backend-owned action `value` payloads
  voor Spotify Direct en Music Assistant blijven intact.
- Demo Mode is volledig lokaal en non-interacting met Home Assistant. Ask DJ
  toont de vaste voorbeelden en geeft client-side demobubbles terug die
  uitleggen dat Ask DJ echt antwoordt zodra Home Assistant gekoppeld is.
- VibeCast toont de backend `context.genre_badge` als duidelijke top-trailing
  genrebadge. In Demo Mode gebruikt VibeCast de lokale Track Insight genredata
  en start automatisch een nieuwe Track Insight analyse als VibeCast open staat
  en de demo-track wisselt.
- VibeCast gebruikt `GET /api/djconnect/v1/vibecast`, rendert
  `items[].text[]` als veilige gestructureerde tekst, stuurt
  `X-DJConnect-Render-Capabilities`, laadt alleen DJConnect image-proxy URLs en
  wist shout-out artwork als een volgende response geen imagevelden bevat.
- Ontdek / Music Discovery is backend-owned via
  `GET /api/djconnect/v1/music_discovery`,
  `POST /api/djconnect/v1/music_discovery/refresh` en
  `POST /api/djconnect/v1/music_discovery/play`. APNs
  `music_discovery_ready` is alleen een trigger om Ontdek te openen/verversen;
  recommendations worden niet uit de pushpayload gerenderd.
- De Mood-keuze is gedeeld tussen Ask DJ, Track Insight en Speelt nu / Now
  Playing. Speelt nu gebruikt dezelfde control op iOS en macOS; de track-art
  kaart kleurt mee met de actieve Mood-palette.
- De statische What's New release-notes voor de actuele app-release worden door
  de `Public unsigned release` workflow gepubliceerd naar
  `pcvantol/djconnect-website` en `djconnect.dev`. Controleer specifiek dat de
  `nl` JSON echte Nederlandse inhoud bevat en niet de Engelse fallback.
- Lokale branch hoort gelijk te lopen met `origin/main`; controleer dat bij
  start van iedere sessie.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - public release tags in `pcvantol/djconnect-app-releases` voor de actuele
    `ios/v...` en `macos/v...` app-release indien release/publicatie geraakt
    wordt.
  - `https://djconnect.dev/release-notes/ios/nl/v<versie>.json` en het macOS
    equivalent indien What's New release-notes geraakt worden.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
