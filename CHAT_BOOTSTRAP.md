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
- Houd cross-repo contracten actueel met `pcvantol/djconnect`, client/firmware repos, `SYNC_PROMPTS.md` en `PRODUCT_ROADMAP.md` indien protocol/roadmap geraakt wordt.
- Secrets/tokens/wachtwoorden/private URLs mogen nooit in commits, logs, screenshots, diagnostics of test fixtures.

Huidige status om te controleren:
- Release `3.1.32` is de actuele source release met device-taalgestuurde UI en
  What's New release-notes, vaste donkere appkleuren in light mode en een
  macOS game-selector in dezelfde iOS-stijl.
- Lokale branch hoort gelijk te lopen met `origin/main`; controleer dat bij
  start van iedere sessie.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - public release tags in `pcvantol/djconnect-app-releases` voor `ios/v3.1.32` en `macos/v3.1.32` indien release/publicatie geraakt wordt.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
