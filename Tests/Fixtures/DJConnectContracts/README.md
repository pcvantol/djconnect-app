# DJConnect Client Contract Fixtures

These golden JSON fixtures are exported for Apple, Raspberry Pi and Windows
client tests. They describe backend-owned payload shapes that clients should
render without rebuilding recommendations, privacy metadata, quality scores or
playback actions locally.

Use:

```sh
python3 tools/export_client_contracts.py --output ../djconnect-pi/tests/fixtures/djconnect_contracts
```

Fixtures:

- `capabilities.websocket.json`
- `music_dna.profile.disabled.json`
- `music_dna.profile.empty.json`
- `music_dna.profile.rich.json`
- `music_discovery.feed.json`
- `ask_dj.recently_played_history.json`

`manifest.json` lists fixture ids, files, transport and contract purpose.
