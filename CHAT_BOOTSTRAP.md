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
- User-facing term is `Client adres`, niet `Client API URL`.
- Clients mogen geen `spotify_source` / "Spotify source override" of `liked_proxy_playlist_uri` / "Standaard playlist override" meer tonen, documenteren of verwachten.
- Backend playback loopt via de Home Assistant DJConnect integration; clients sturen generieke playback commands.
- Apple clients bewaren alleen het door Home Assistant uitgegeven DJConnect device-token in app-private storage. Gebruik geen Keychain en toon geen Keychain-permissie of fallback-popup. `App opnieuw koppelen` wist lokale pairing/token-state, roteert de lokale clientidentiteit/koppelcode waar nodig en opent opnieuw de pairingflow.
- Houd cross-repo contracten actueel met `pcvantol/djconnect`, client/firmware repos, `SYNC_PROMPTS.md` en `PRODUCT_ROADMAP.md` indien protocol/roadmap geraakt wordt. Apple clients gebruiken Ask DJ als rijke chat/PTT-functie; er is geen losse Now Playing `DJ verzoek` ingang meer. rbpi had die losse ingang al niet; ESP32 krijgt geen Ask DJ rich UI en blijft buiten Apple UI-sync.
- Ask DJ is cross-device: iOS, macOS en watchOS synchroniseren history via Home Assistant en cachen lokaal voor performance. Clients mergen serverberichten in de lokale cache en vervangen de lokale lijst niet door een bounded response-window. `clear_revision` blijft de full-clear authority.
- Ask DJ history ondersteunt assistant-only systeemmeldingen met `message_kind: "system"`, onder andere `origin: "spotify_playback_context"` voor DJ-feitjes en `origin: "history_retention"` voor limietmeldingen. Deze berichten hebben geen voorafgaande user bubble nodig en zijn niet retrybaar.
- History retention gebruikt backendmetadata zoals `history_limit`, `history_trimmed_before` en `history_trimmed_count`; clients mogen lokale cache ouder dan `history_trimmed_before` opschonen zonder displaytekst te parsen.
- Ask DJ tekstchat stuurt standaard `audio_response: "auto"`. Ontbrekende `audio_url` is normaal; replay/audio UI verschijnt alleen als `assistant_message.audio_url` of top-level `audio_url` aanwezig is.
- On Air is de Apple woonkamer/AirPlay-uitvoer vanuit het bestaande Ask DJ
  scherm. Het is geen aparte app-route of backendcontract: de Ask DJ toolbar
  toont de AirPlay route picker, de tv krijgt grote chatbubbles en now-playing
  artwork, en automatische DJ `audio_url` playback volgt dezelfde
  Ask DJ/audio-pipeline.
- Ask DJ mag informatieve vragen, contextuele vervolgreacties, playback-intents, persoonlijke muziekanalyse, aanbevelingen, Play Now-acties, afbeeldingen, links, bronnen en DJ-audio bevatten. Intentinterpretatie blijft backend-owned; clients hardcoden geen intentfamilies behalve UI-weergave van teruggegeven media/actions.
- Ask DJ request payloads mogen optionele `metadata` bevatten voor backend-owned context triggers. De geplande ochtend-start gebruikt `metadata.trigger == "morning_startup"` met tekst `Goedemorgen`/`Good morning` als de app 's ochtends start zonder actieve playback; Home Assistant hoort daarop een normale Ask DJ response/follow-up te maken en niet client-side automatisch muziek te starten.
- Backend follow-up/confirmatievragen worden als Ask DJ `playback_actions` gerenderd. Voor algemene ja/nee verduidelijking gebruikt de backend acties met bijvoorbeeld `kind: "confirmation"`, `action_style: "confirmation"`, `response_value: "yes"|"no"` en `command: "ask_dj_followup_response"`. Clients tonen dan klikbare Ja/Nee knoppen; de pending follow-up state en uiteindelijke intentuitvoering blijven server-side.
- Raw backend/proxy/decode/HTML-fouten mogen nooit in de Ask DJ chat UI verschijnen. Toon korte gelokaliseerde meldingen zoals `Ask DJ niet bereikbaar` of `Home Assistant gaf geen antwoord`; technische details blijven in diagnostics/logs.
- Secrets/tokens/wachtwoorden/private URLs mogen nooit in commits, logs, screenshots, diagnostics of test fixtures.

Huidige status om te controleren:
- Release `3.1.43` is de actuele source release met rijke Ask DJ assistant
  message rendering, gestructureerde playback/action-lijsten zonder stale
  artwork, On Air range-request support, watchOS runtimeverbeteringen,
  `3.1.42` reset-confirmatie, `3.1.41` push/watchOS-uitbreidingen en alle
  `3.1.40` On Air wijzigingen.
- watchOS volgt dezelfde pairingrichting als iOS/macOS: de Watch adverteert de
  lokale client API via mDNS, Home Assistant vult de koppelcode in de config
  flow in, de gebruiker bevestigt in Home Assistant, en de Watch toont daarna
  `Succesvol gekoppeld`. De Watch heeft Ask DJ PTT/voice input, tekstuele
  history, optionele replay van `audio_url`, en ontvangt dezelfde backend
  system/ambient historyberichten.
- Demo Mode is volledig lokaal en non-interacting met Home Assistant. Ask DJ
  toont de vaste voorbeelden en geeft client-side demobubbles terug die
  uitleggen dat Ask DJ echt antwoordt zodra Home Assistant gekoppeld is.
- De statische What's New release-notes voor `3.1.43` worden door de
  `Public unsigned release` workflow gepubliceerd naar `pcvantol/djconnect-website`
  en `djconnect.dev`. Controleer de workflowstatus als release/publicatie
  geraakt wordt.
- Lokale branch hoort gelijk te lopen met `origin/main`; controleer dat bij
  start van iedere sessie.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - public release tags in `pcvantol/djconnect-app-releases` voor `ios/v3.1.43` en `macos/v3.1.43` indien release/publicatie geraakt wordt.
  - `https://djconnect.dev/release-notes/ios/nl/v3.1.43.json` en het macOS
    equivalent indien What's New release-notes geraakt worden.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
