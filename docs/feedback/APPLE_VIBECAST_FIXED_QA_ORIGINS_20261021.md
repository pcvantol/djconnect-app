# Fixed VibeCast QA origin binding

This bounded source increment follows protected Apple main
`b4de259bceb612a9847aaf8fe6ec7fc1d50e1fde`. The existing QR parser admitted only
production, encrypted destinations named the production browser, and recovery
validation and persistent journals were bound to production. A separate QA
build therefore could not consistently consume the pinned API QA contract.

`RendezvousBuildProfile` now selects one immutable compile-time tuple. The normal
shipping project has no QA condition and keeps its exact original production
origins and Keychain service names. The isolated generator defines the QA
condition, separate application/URL-scheme identities and separate journal
service names. Parser admission, all public service request URLs, encrypted
destination browser origin and recover-key client-data validation use the same
selected environment. HA pairing trust is unchanged.

The two checked-in API fixtures are exact bytes from protected API source
`3b43332bb28ed4aea228938f2d3a61796c8c3f33`, run `39615718356`, artifact
`12352870721`. The published ZIP digest and the extracted fixture hashes were
verified before use. No API or receiver source was changed.

| Verification | Actual result |
| --- | --- |
| Before product fix, isolated QA parser test | Failed: production origin selected and QA QR rejected |
| Production Rendezvous regressions | 71 XCTest + 83 Swift Testing tests passed; zero failures |
| Separate QA contract suite | 13 XCTest + 6 Swift Testing tests passed; zero failures |
| Unsigned iOS/iPadOS QA app build | Passed using actual app/Core/UI sources |
| Build readback | QA bundle ID, display name, URL scheme and flavor verified; no embedded signing profile or signature directory |
| Source-input readback | All 168 recorded input hashes matched; app compilation inputs unchanged by final test-only corrections |
| Production configuration | No QA compilation condition in shipping project or project.yml |

The tests cover exact cross-environment rejection and URL variants, intercepted
HTTP URL/body/credential behavior, decrypted destination contents, and recovery
admission before any persistence. HTTP interception and journal storage are
in-memory; the existing encryption test uses an ephemeral test RSA key. No App
Attest SDK/key generation, real Keychain mutation, real service call, signing,
installation, HA/provider operation or service activation was performed.

Initial qualification attempts found and corrected a nested Swift Testing macro,
QA icon selection, fixture subdirectory lookup, URLProtocol streamed request
capture and a production-only literal in a negative recovery test. Their failed
logs remain preserved; only the final successful executions are counted above.

See [generator instructions](../../Tools/qualification/vibecast-fixed-qa/README.md)
and the adjacent [portable evidence receipt](APPLE_VIBECAST_FIXED_QA_ORIGINS_20261021.json).
The generated project references working source with hashed input provenance;
it is not a published signed Apple artifact or operational admission. Existing
`notReady` SDK orchestration remains open, as do full receiver/HA/TV-chain and
physical-device acceptance. Music DNA artwork, current-subject Track Insight and
exact historical-track playback still require qualified Core contracts.
