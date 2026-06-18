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
- Release `3.1.33` is de actuele source release met GitHub security hardening
  voor secret scanning, push protection, Dependabot alerts/security updates en
  branch protection op `main`.
- De statische What's New release-notes voor `3.1.33` zijn handmatig
  gepubliceerd naar `pcvantol/djconnect-website` en live op `djconnect.dev`.
  De public unsigned artifact releases `ios/v3.1.33` en `macos/v3.1.33`
  ontbreken nog zolang de `Public unsigned release` workflow niet groen is.
- Lokale branch hoort gelijk te lopen met `origin/main`; controleer dat bij
  start van iedere sessie.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - public release tags in `pcvantol/djconnect-app-releases` voor `ios/v3.1.33` en `macos/v3.1.33` indien release/publicatie geraakt wordt.
  - `https://djconnect.dev/release-notes/ios/nl/v3.1.33.json` en het macOS
    equivalent indien What's New release-notes geraakt worden.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
