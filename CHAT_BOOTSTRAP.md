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
- Dit is de native DJConnect app repo voor iOS/iPadOS/macOS.
- DJConnect wordt ontwikkeld en onderhouden met AI-assisted/agentic engineering workflows, inclusief Codex; accepted changes blijven maintainer-reviewed en prompts/logs/issues mogen geen secrets of private data bevatten.
- Project is MIT-licensed; zie `LICENSE`.
- User-facing term is `Client adres`, niet `Client API URL`.
- Clients mogen geen `spotify_source` / "Spotify source override" of `liked_proxy_playlist_uri` / "Standaard playlist override" meer tonen, documenteren of verwachten.
- Backend playback loopt via de Home Assistant DJConnect integration; clients sturen generieke playback commands.
- Houd cross-repo contracten actueel met `pcvantol/djconnect`, client/firmware repos, `SYNC_PROMPTS.md` en `PRODUCT_ROADMAP.md` indien protocol/roadmap geraakt wordt. Apple clients gebruiken Ask DJ als rijke chat/PTT-functie; er is geen losse Now Playing `DJ verzoek` ingang meer. rbpi had die losse ingang al niet; ESP32 krijgt geen Ask DJ rich UI en blijft buiten Apple UI-sync.
- Secrets/tokens/wachtwoorden/private URLs mogen nooit in commits, logs, screenshots, diagnostics of test fixtures.

Huidige status om te controleren:
- Release `3.1.36` is de actuele source release met de native watchOS client,
  Ask DJ chat op iOS/macOS/watchOS, rijke Ask DJ media/actions, Watch pairing
  via mDNS/local device API, Ask DJ `audio_response: auto`, en geen losse
  Now Playing `DJ verzoek` UI meer op Apple clients.
- De statische What's New release-notes voor `3.1.36` worden door de
  `Public unsigned release` workflow gepubliceerd naar `pcvantol/djconnect-website`
  en `djconnect.dev`. Controleer de workflowstatus als release/publicatie
  geraakt wordt.
- Lokale branch hoort gelijk te lopen met `origin/main`; controleer dat bij
  start van iedere sessie.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - public release tags in `pcvantol/djconnect-app-releases` voor `ios/v3.1.36` en `macos/v3.1.36` indien release/publicatie geraakt wordt.
  - `https://djconnect.dev/release-notes/ios/nl/v3.1.36.json` en het macOS
    equivalent indien What's New release-notes geraakt worden.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
