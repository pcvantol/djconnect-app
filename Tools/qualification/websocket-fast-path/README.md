# Native shared WebSocket qualification

`WebSocketNativeConcurrencyTests` uses Foundation's real WebSocket SDK against
`server.js`. The server binds an ephemeral port on 127.0.0.1 and uses synthetic
fixture-only credentials. Each case owns its process, HTTP session and report
file; teardown terminates that process and drains its sockets. Node must be on
PATH. No Home Assistant, user pairing or provider is contacted.

Run from the repository with an external per-run scratch/cache/TMPDIR:

```sh
swift test --parallel --filter WebSocketNativeConcurrencyTests --scratch-path "$DJC_TEST_ROOT/swift"
```

The fixture follows protected Core cc8039d42ea5bc27330aab1af54ba0dcca3bb054:
capabilities requires HA authentication plus type/id, without a DJConnect
identity; business commands validate the fixture DJConnect identity. Control
endpoints hold/release auth, reverse replies, close sockets and inject invalid
frames. They are test instrumentation, not a product API or authority source.
Manual test scheduling is local-only. No push clock or producer validity is
inferred from receiving a frame. Native tests are macOS-only and included in the
Xcode core test target as well as SwiftPM. They do not qualify physical devices,
real HA/provider operation, push delivery or distribution.
