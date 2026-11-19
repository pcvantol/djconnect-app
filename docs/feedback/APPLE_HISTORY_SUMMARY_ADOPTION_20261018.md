# Apple owner history summary adoption

Slice: `HISTORY::APPLE::SUMMARY`, existing Apple writer, new branch from source-main `abcb7316d3189123302c7bddecf1815a3284ab56`.

## Producer and scope

Consume the already delivered Core contract `djconnect-session-history-summary/1`, source pin `ccbb839f4e544b3739c31202685d147207e4c289`. The list/detail/state fixtures are copied byte-for-byte from that Git object; their SHA256 provenance is recorded in `Tests/Fixtures/session-history-summary-provenance.json`. No Core source, contract, migration or backend authority was changed.

The existing private owner list rows and archive headers render registered track observations, semantic DJ publication counts, optional retained contribution counts, and predominant symbolic Mood. The exact capability plus version1 is required. Counts come only from the containing server header, never loaded entries, progress/queue/title heuristics or the current Mood. No extra request, timeline fan-out or new timer was introduced.

List integer revisions and detail opaque string revisions remain distinct. Every summary and metric must match its containing header revision, scalar type, state and exact snapshot as_of. Unsupported/malformed/incoherent optional summaries are omitted while the otherwise valid Session remains readable. Same-revision refresh responses can still update as_of through existing list/detail replacement; no revision sorting or local predominant-Mood computation exists.

Known zero, positive complete counts, partial registered subsets, unknown and withdrawn values remain separate. Unknown/withdrawn are not zero. Predominant Mood requires complete coverage and a known symbolic value or mixed; missing values never borrow current/start Mood. Five-language labels explain that observations are not full listens or exact playback occurrences. Final does not imply complete coverage. Missing summaries on legacy Sessions add no invented values.

The projection stays in the existing owner-history memory/read boundary. It is not added to passive surfaces, App Groups, notifications, Watch snapshots, VibeCast or diagnostics. Owner reset/suspend withdraws the presentation capability. Text wraps without fixed line count/height; accessibility combines each summary for reading.

## Qualification

- Six focused tests /29 cases pass: real list/detail/state fixtures and Codable round trips, 18 malformed/misbound optional-data cases, exact capability versions and five-language unknown/withdrawn/partial presentation.
- Full Swift suite: **840 tests /10 suites PASS91.736s**.
- Localization validation: **1313 keys /five languages PASS**; diff hygiene PASS.
- Native signed ordinary40336 Mac and iOS/Watch/widget builds PASS; strict signatures and zero embedded test bundles PASS.
- Generated Xcode project adds exactly the three new Swift source/test files from the clean stage. Seven pre-existing recovery duplicate paths remain excluded and preserved.

## Remaining boundaries

Native visual/VoiceOver/Dynamic Type acceptance and actual paired-device summary rendering are not yet qualified. Native XCTest IDE-session startup remains an environment blocker from the previous source delivery. USB scroll profiling is still explicitly deferred until tomorrow. Ordinary40336 installed/read back and opened on iPad, MacBook and Mac mini. Previous Mac apps are preserved; pairing/Profile data is retained. iPhone/Watch remain unavailable/last confirmed40331. This is installation proof, not actual paired summary/visual/accessibility acceptance. Source review/protected delivery is not claimed.

The prior UI/history source is protected-merged via PR115/main `abcb7316d3189123302c7bddecf1815a3284ab56`, with all candidate checks green and the ordinary main CI job (tests/Mac/iOS builds) passing. Its separate native main coverage failed before test execution; the per-user service recovery was refused by macOS SIP, without any security bypass. Consequently full post-merge release-evidence qualification remains open. Session deletion remains producer-gated; original404, queue rendering, physical speech and performance findings are not closed by this slice.
