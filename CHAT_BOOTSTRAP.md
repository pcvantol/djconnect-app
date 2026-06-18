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
- Project is MIT-licensed; zie `LICENSE`.
- User-facing term is `Client adres`, niet `Client API URL`.
- Clients mogen geen `spotify_source` / "Spotify source override" of `liked_proxy_playlist_uri` / "Standaard playlist override" meer tonen, documenteren of verwachten.
- Backend playback loopt via de Home Assistant DJConnect integration; clients sturen generieke playback commands.
- Houd cross-repo contracten actueel met `pcvantol/djconnect`, client/firmware repos, `SYNC_PROMPTS.md` en `PRODUCT_ROADMAP.md` indien protocol/roadmap geraakt wordt.
- Secrets/tokens/wachtwoorden/private URLs mogen nooit in commits, logs, screenshots, diagnostics of test fixtures.

Huidige status om te controleren:
- Release `3.1.29` is gemaakt en gepusht naar GitHub.
- `CONTRIBUTING.md` is toegevoegd maar mogelijk nog uncommitted.
- Check direct:
  - `git status --short --branch`
  - `gh run list --repo pcvantol/djconnect-app --limit 5`
  - eventueel public release tags in `pcvantol/djconnect-app-releases` voor `ios/v3.1.29` en `macos/v3.1.29`.

Werkstijl:
- Gebruik `rg` voor zoeken.
- Gebruik `apply_patch` voor handmatige edits.
- Reverteer geen bestaande user changes.
- Voor release: gebruik `./release.sh <versie>` of `./release.sh <versie> --skip-tests` alleen als daar reden voor is.
- Voor docs-only wijziging: minimaal `git diff --check`.
- Antwoord in het Nederlands, kort en praktisch.
```
